"""
Bronze Ingestion - Landing -> Bronze (Iceberg)

Le os arquivos parquet da camada Landing (gerados pelo DMS a partir do RDS)
e grava como tabelas Iceberg na camada Bronze, registradas no Glue Catalog.

Quando os dados possuem colunas CDC do DMS (Op e dms_load_timestamp):
  - Deduplica mantendo apenas o registro mais recente por chave
  - Remove registros marcados como Delete (Op = 'D')

Execucao:
  spark-submit --deploy-mode client s3://luana-lab-data-lake-spark/bronze_ingestion.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, input_file_name, lit, col, row_number
from pyspark.sql.window import Window

# Caminhos dos buckets S3
BUCKET_LANDING = "s3://luana-lab-data-lake-landing"
BUCKET_BRONZE = "s3://luana-lab-data-lake-bronze"

# Database no Glue Catalog
DATABASE = "luana_lab_bronze"

# Tabelas e suas chaves primarias para deduplicacao
TABELAS = {
    "customers":                        ["customer_id"],
    "geolocation":                      ["geolocation_id"],
    "order_items":                      ["order_id", "order_item_id"],
    "order_payments":                   ["order_id", "payment_sequential"],
    "order_reviews":                    ["review_id"],
    "orders":                           ["order_id"],
    "products":                         ["product_id"],
    "sellers":                          ["seller_id"],
    "product_category_name_translation": ["product_category_name"],
}


def criar_spark_session():
    """Cria a sessao Spark com o catalogo Iceberg apontando para o Glue."""
    return (
        SparkSession.builder
        .appName("luana-lab-bronze-ingestion")
        .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
        .config("spark.sql.catalog.glue_catalog.warehouse", BUCKET_BRONZE)
        .config("spark.sql.catalog.glue_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .getOrCreate()
    )


def processar_tabela(spark, tabela, chaves, indice, total):
    """
    Processa uma tabela da Landing para o Bronze.

    1. Le os parquets da landing (path: s3://landing/public/<tabela>/)
    2. Adiciona colunas de metadados (_ingestion_timestamp, _source_file, _source_table)
    3. Se houver CDC (colunas Op e dms_load_timestamp):
       - Deduplica por chave, mantendo o registro mais recente
       - Remove deletes (Op = 'D')
    4. Grava como tabela Iceberg no Glue Catalog (CREATE ou OVERWRITE)
    """
    print(f"\n[{indice}/{total}] Processando: {tabela}")
    print(f"  Chaves: {chaves}")

    caminho_landing = f"{BUCKET_LANDING}/public/{tabela}/"
    print(f"  Lendo parquet de: {caminho_landing}")

    try:
        df = spark.read.parquet(caminho_landing)
    except Exception as e:
        print(f"  [SKIP] Erro ao ler: {e}")
        return

    qtd_landing = df.count()
    print(f"  Registros na landing: {qtd_landing}")

    if qtd_landing == 0:
        print(f"  [SKIP] Sem dados na landing")
        return

    print(f"  Colunas encontradas: {df.columns}")

    # Adiciona colunas de auditoria/metadados
    df_bronze = (
        df
        .withColumn("_ingestion_timestamp", current_timestamp())
        .withColumn("_source_file", input_file_name())
        .withColumn("_source_table", lit(tabela))
    )

    # Tratamento CDC: deduplica por chave e remove deletes
    if "Op" in df_bronze.columns and "dms_load_timestamp" in df_bronze.columns:
        qtd_antes = df_bronze.count()
        window = Window.partitionBy(*chaves).orderBy(col("dms_load_timestamp").desc())
        df_bronze = (
            df_bronze
            .withColumn("_rn", row_number().over(window))
            .filter(col("_rn") == 1)
            .drop("_rn")
            .filter((col("Op") != "D") | col("Op").isNull())
        )
        qtd_depois = df_bronze.count()
        print(f"  CDC deduplicado: {qtd_antes} -> {qtd_depois} registros (removidos duplicados e deletes)")

    # Grava no Iceberg: cria tabela nova ou sobrescreve existente
    tabela_iceberg = f"glue_catalog.{DATABASE}.{tabela}"

    if spark.catalog.tableExists(tabela_iceberg):
        print(f"  Tabela {tabela_iceberg} existe -> OVERWRITE")
        df_bronze.writeTo(tabela_iceberg).overwritePartitions()
        print(f"  Overwrite concluido")
    else:
        print(f"  Tabela {tabela_iceberg} nao existe -> CREATE")
        df_bronze.writeTo(tabela_iceberg).using("iceberg").create()
        print(f"  Tabela criada com sucesso")

    contagem = spark.table(tabela_iceberg).count()
    print(f"  [OK] {tabela}: {contagem} registros no bronze")


def main():
    spark = criar_spark_session()

    print("=" * 60)
    print("BRONZE INGESTION - Landing -> Bronze (Iceberg)")
    print("=" * 60)

    total = len(TABELAS)
    for indice, (tabela, chaves) in enumerate(TABELAS.items(), 1):
        processar_tabela(spark, tabela, chaves, indice, total)

    print("=" * 60)
    print("BRONZE INGESTION FINALIZADA")
    print("=" * 60)

    spark.stop()


if __name__ == "__main__":
    main()
