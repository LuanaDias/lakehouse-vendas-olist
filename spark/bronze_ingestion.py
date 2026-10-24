from pyspark.sql import SparkSession
from pyspark.sql.functions import current_timestamp, input_file_name, lit, col, row_number
from pyspark.sql.window import Window

BUCKET_LANDING = "s3://luana-lab-data-lake-landing"
BUCKET_BRONZE = "s3://luana-lab-data-lake-bronze"
DATABASE = "luana_lab_bronze"

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

    df_bronze = (
        df
        .withColumn("_ingestion_timestamp", current_timestamp())
        .withColumn("_source_file", input_file_name())
        .withColumn("_source_table", lit(tabela))
    )

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
