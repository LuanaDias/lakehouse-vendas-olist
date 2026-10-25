"""
Silver CDC - Bronze -> Silver (Iceberg MERGE INTO)

Le as tabelas Iceberg da camada Bronze e aplica transformacoes para a camada Silver:
  - Deduplicacao por chave primaria (mantém registro mais recente)
  - CDC com MERGE INTO: upsert (insert/update) e delete
  - Tipagem: cast de colunas para tipos corretos (int, double, timestamp)
  - Padronizacao: trim + lower/upper em campos textuais (cidades, estados)
  - Remove colunas de metadados da bronze (Op, dms_load_timestamp, etc.)

A silver mantem o estado atual de cada entidade (visao mais recente).
Suporta time travel do Iceberg (snapshots e historico).

Execucao:
  spark-submit --deploy-mode client s3://luana-lab-data-lake-spark/silver_cdc.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    current_timestamp, col, trim, lower, upper, row_number,
    to_timestamp, when, lit
)
from pyspark.sql.window import Window
from pyspark.sql.types import (
    IntegerType, DoubleType, LongType
)

# Caminhos dos buckets S3
BUCKET_BRONZE = "s3://luana-lab-data-lake-bronze"
BUCKET_SILVER = "s3://luana-lab-data-lake-silver"

# Databases no Glue Catalog
DB_BRONZE = "luana_lab_bronze"
DB_SILVER = "luana_lab_silver"

# Configuracao de cada tabela:
#   chaves     - colunas que formam a chave primaria (usadas no MERGE e deduplicacao)
#   tipos      - cast de colunas para o tipo correto
#   padronizar - lower/upper + trim em colunas textuais
TABELAS = {
    "customers": {
        "chaves": ["customer_id"],
        "tipos": {
            "customer_zip_code_prefix": IntegerType(),
        },
        "padronizar": {
            "lower": ["customer_city"],
            "upper": ["customer_state"],
        },
    },
    "orders": {
        "chaves": ["order_id"],
        "tipos": {
            "order_purchase_timestamp": "timestamp",
            "order_approved_at": "timestamp",
            "order_delivered_carrier_date": "timestamp",
            "order_delivered_customer_date": "timestamp",
            "order_estimated_delivery_date": "timestamp",
        },
        "padronizar": {
            "lower": ["order_status"],
        },
    },
    "order_items": {
        "chaves": ["order_id", "order_item_id"],
        "tipos": {
            "order_item_id": IntegerType(),
            "price": DoubleType(),
            "freight_value": DoubleType(),
            "shipping_limit_date": "timestamp",
        },
        "padronizar": {},
    },
    "order_payments": {
        "chaves": ["order_id", "payment_sequential"],
        "tipos": {
            "payment_sequential": IntegerType(),
            "payment_installments": IntegerType(),
            "payment_value": DoubleType(),
        },
        "padronizar": {
            "lower": ["payment_type"],
        },
    },
    "order_reviews": {
        "chaves": ["review_id"],
        "tipos": {
            "review_score": IntegerType(),
            "review_creation_date": "timestamp",
            "review_answer_timestamp": "timestamp",
        },
        "padronizar": {},
    },
    "products": {
        "chaves": ["product_id"],
        "tipos": {
            "product_name_lenght": IntegerType(),
            "product_description_lenght": IntegerType(),
            "product_photos_qty": IntegerType(),
            "product_weight_g": DoubleType(),
            "product_length_cm": DoubleType(),
            "product_height_cm": DoubleType(),
            "product_width_cm": DoubleType(),
        },
        "padronizar": {
            "lower": ["product_category_name"],
        },
    },
    "sellers": {
        "chaves": ["seller_id"],
        "tipos": {
            "seller_zip_code_prefix": IntegerType(),
        },
        "padronizar": {
            "lower": ["seller_city"],
            "upper": ["seller_state"],
        },
    },
    "geolocation": {
        "chaves": ["geolocation_id"],
        "tipos": {
            "geolocation_zip_code_prefix": IntegerType(),
            "geolocation_lat": DoubleType(),
            "geolocation_lng": DoubleType(),
        },
        "padronizar": {
            "lower": ["geolocation_city"],
            "upper": ["geolocation_state"],
        },
    },
    "product_category_name_translation": {
        "chaves": ["product_category_name"],
        "tipos": {},
        "padronizar": {
            "lower": ["product_category_name", "product_category_name_english"],
        },
    },
}

# Colunas de metadados da bronze que nao devem ir para a silver
COLUNAS_META_BRONZE = ["Op", "dms_load_timestamp", "_source_file", "_source_table"]


def criar_spark_session():
    """Cria a sessao Spark com catalogo Iceberg apontando para o Glue e bucket Silver."""
    return (
        SparkSession.builder
        .appName("luana-lab-silver-cdc")
        .config("spark.sql.catalog.glue_catalog", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.glue_catalog.catalog-impl", "org.apache.iceberg.aws.glue.GlueCatalog")
        .config("spark.sql.catalog.glue_catalog.warehouse", BUCKET_SILVER)
        .config("spark.sql.catalog.glue_catalog.io-impl", "org.apache.iceberg.aws.s3.S3FileIO")
        .config("spark.sql.extensions", "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions")
        .getOrCreate()
    )


def aplicar_tipos(df, tipos):
    """Faz cast das colunas para os tipos corretos (int, double, timestamp)."""
    for coluna, tipo in tipos.items():
        if coluna not in df.columns:
            continue
        if tipo == "timestamp":
            df = df.withColumn(coluna, to_timestamp(col(coluna)))
        else:
            df = df.withColumn(coluna, col(coluna).cast(tipo))
    return df


def aplicar_padronizacao(df, padronizar):
    """Aplica trim + lower ou upper nas colunas textuais (cidades, estados, etc.)."""
    for coluna in padronizar.get("lower", []):
        if coluna in df.columns:
            df = df.withColumn(coluna, lower(trim(col(coluna))))
    for coluna in padronizar.get("upper", []):
        if coluna in df.columns:
            df = df.withColumn(coluna, upper(trim(col(coluna))))
    return df


def deduplicar(df, chaves):
    """Remove duplicatas mantendo o registro mais recente por chave primaria."""
    if "_ingestion_timestamp" in df.columns:
        window = Window.partitionBy(*chaves).orderBy(col("_ingestion_timestamp").desc())
    else:
        window = Window.partitionBy(*chaves).orderBy(lit(1))
    return (
        df
        .withColumn("_rn", row_number().over(window))
        .filter(col("_rn") == 1)
        .drop("_rn")
    )


def remover_colunas_meta(df):
    """Remove colunas de metadados da bronze que nao devem ir para a silver."""
    colunas_remover = [c for c in COLUNAS_META_BRONZE if c in df.columns]
    return df.drop(*colunas_remover)


def processar_tabela(spark, tabela, config, indice, total):
    """
    Processa uma tabela da Bronze para a Silver.

    Pipeline:
      1. Le a tabela Iceberg do Bronze
      2. Separa registros de delete (Op='D') dos demais
      3. Deduplica por chave primaria
      4. Remove colunas de metadados da bronze
      5. Aplica tipagem (cast) e padronizacao (trim/lower/upper)
      6. Adiciona _silver_timestamp
      7. MERGE INTO na Silver (upsert: insert novos + update existentes)
      8. DELETE na Silver para registros marcados como deletados no CDC
    """
    print(f"\n[{indice}/{total}] Processando: {tabela}")

    chaves = config["chaves"]
    tipos = config.get("tipos", {})
    padronizar = config.get("padronizar", {})

    tabela_bronze = f"glue_catalog.{DB_BRONZE}.{tabela}"
    tabela_silver = f"glue_catalog.{DB_SILVER}.{tabela}"

    if not spark.catalog.tableExists(tabela_bronze):
        print(f"  [SKIP] Tabela bronze {tabela_bronze} nao existe")
        return

    df = spark.table(tabela_bronze)
    qtd_bronze = df.count()
    print(f"  Registros no bronze: {qtd_bronze}")

    if qtd_bronze == 0:
        print(f"  [SKIP] Sem dados no bronze")
        return

    # Verifica se os dados possuem colunas CDC do DMS
    tem_cdc = "Op" in df.columns

    # Separa deletes dos inserts/updates
    if tem_cdc:
        df_deletes = df.filter(col("Op") == "D").select(*chaves)
        df = df.filter((col("Op") != "D") | col("Op").isNull())

    # Transformacoes: dedup -> remove meta -> tipagem -> padronizacao
    df = deduplicar(df, chaves)
    df = remover_colunas_meta(df)
    df = aplicar_tipos(df, tipos)
    df = aplicar_padronizacao(df, padronizar)
    df = df.withColumn("_silver_timestamp", current_timestamp())

    # Se a tabela silver nao existe, cria com os dados
    if not spark.catalog.tableExists(tabela_silver):
        print(f"  Tabela {tabela_silver} nao existe -> CREATE")
        df.writeTo(tabela_silver).using("iceberg").create()
        contagem = spark.table(tabela_silver).count()
        print(f"  [OK] {tabela}: {contagem} registros na silver (criada)")
        return

    # MERGE INTO: upsert (matched = update, not matched = insert)
    print(f"  Tabela {tabela_silver} existe -> MERGE (upsert)")

    df.createOrReplaceTempView(f"source_{tabela}")

    condicao_join = " AND ".join([f"target.{k} = source.{k}" for k in chaves])
    colunas_update = [c for c in df.columns if c not in chaves]
    set_clause = ", ".join([f"target.{c} = source.{c}" for c in colunas_update])
    insert_cols = ", ".join(df.columns)
    insert_vals = ", ".join([f"source.{c}" for c in df.columns])

    merge_sql = f"""
        MERGE INTO {tabela_silver} AS target
        USING source_{tabela} AS source
        ON {condicao_join}
        WHEN MATCHED THEN UPDATE SET {set_clause}
        WHEN NOT MATCHED THEN INSERT ({insert_cols}) VALUES ({insert_vals})
    """

    spark.sql(merge_sql)
    print(f"  MERGE concluido")

    # DELETE: remove registros marcados como deletados no CDC
    if tem_cdc and df_deletes.count() > 0:
        qtd_deletes = df_deletes.count()
        df_deletes.createOrReplaceTempView(f"deletes_{tabela}")

        delete_sql = f"""
            DELETE FROM {tabela_silver}
            WHERE ({", ".join(chaves)}) IN (SELECT {", ".join(chaves)} FROM deletes_{tabela})
        """
        spark.sql(delete_sql)
        print(f"  DELETE: {qtd_deletes} registros removidos")

    contagem = spark.table(tabela_silver).count()
    print(f"  [OK] {tabela}: {contagem} registros na silver")


def demo_time_travel(spark):
    """
    Demonstra o time travel do Iceberg na tabela orders.
    Exibe os ultimos snapshots e o historico de versoes.
    """
    print("\n" + "=" * 60)
    print("DEMO TIME TRAVEL - Iceberg")
    print("=" * 60)

    tabela = f"glue_catalog.{DB_SILVER}.orders"

    if not spark.catalog.tableExists(tabela):
        print("  Tabela orders nao existe na silver, pulando demo")
        return

    # Lista os ultimos snapshots (cada snapshot = uma versao da tabela)
    snapshots = spark.sql(f"SELECT snapshot_id, committed_at FROM {tabela}.snapshots ORDER BY committed_at DESC LIMIT 5")
    print("\n  Ultimos snapshots:")
    snapshots.show(truncate=False)

    # Lista o historico de alteracoes
    history = spark.sql(f"SELECT * FROM {tabela}.history ORDER BY made_current_at DESC LIMIT 5")
    print("\n  Historico:")
    history.show(truncate=False)

    contagem_atual = spark.table(tabela).count()
    print(f"\n  Registros atuais: {contagem_atual}")


def main():
    spark = criar_spark_session()

    # Cria o database silver no Glue se nao existir
    spark.sql(f"CREATE DATABASE IF NOT EXISTS glue_catalog.{DB_SILVER}")

    print("=" * 60)
    print("SILVER CDC - Bronze -> Silver (Iceberg MERGE INTO)")
    print("=" * 60)

    total = len(TABELAS)
    for indice, (tabela, config) in enumerate(TABELAS.items(), 1):
        processar_tabela(spark, tabela, config, indice, total)

    # Demonstracao de time travel ao final do processamento
    demo_time_travel(spark)

    print("\n" + "=" * 60)
    print("SILVER CDC FINALIZADA")
    print("=" * 60)

    spark.stop()


if __name__ == "__main__":
    main()
