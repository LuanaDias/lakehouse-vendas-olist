import json
import csv
from pathlib import Path

import boto3
import psycopg2


# ============================================================
# CONFIGURAÇÕES
# ============================================================

# Caminho relativo ao projeto:
# scripts-olist/ -> raiz do projeto -> base_olist/
PASTA_CSV = Path(__file__).resolve().parent.parent / "base_csv_olist"

AWS_REGION = "us-east-1"
RDS_INSTANCE_ID = "luana-lab-postgresql"


# ============================================================
# ARQUIVO CSV -> TABELA POSTGRESQL
# ============================================================

ARQUIVOS = {
    "olist_customers_dataset.csv": "customers",
    "olist_geolocation_dataset.csv": "geolocation",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "order_payments",
    "olist_order_reviews_dataset.csv": "order_reviews",
    "olist_orders_dataset.csv": "orders",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": (
        "product_category_name_translation"
    ),
}


# ============================================================
# ESTRUTURA DAS TABELAS
# ============================================================

SCHEMAS = {

    "customers": """
        CREATE TABLE public.customers (
            customer_id VARCHAR(50) NOT NULL,
            customer_unique_id VARCHAR(50),
            customer_zip_code_prefix INTEGER,
            customer_city VARCHAR(100),
            customer_state VARCHAR(10),

            CONSTRAINT pk_customers
                PRIMARY KEY (customer_id)
        )
    """,

    "geolocation": """
        CREATE TABLE public.geolocation (
            geolocation_id BIGINT GENERATED ALWAYS AS IDENTITY,
            geolocation_zip_code_prefix INTEGER,
            geolocation_lat NUMERIC(10, 6),
            geolocation_lng NUMERIC(10, 6),
            geolocation_city VARCHAR(100),
            geolocation_state VARCHAR(10),

            CONSTRAINT pk_geolocation
                PRIMARY KEY (geolocation_id)
        )
    """,

    "order_items": """
        CREATE TABLE public.order_items (
            order_id VARCHAR(50) NOT NULL,
            order_item_id INTEGER NOT NULL,
            product_id VARCHAR(50),
            seller_id VARCHAR(50),
            shipping_limit_date TIMESTAMP,
            price NUMERIC(12, 2),
            freight_value NUMERIC(12, 2),

            CONSTRAINT pk_order_items
                PRIMARY KEY (order_id, order_item_id)
        )
    """,

    "order_payments": """
        CREATE TABLE public.order_payments (
            order_id VARCHAR(50) NOT NULL,
            payment_sequential INTEGER NOT NULL,
            payment_type VARCHAR(50),
            payment_installments INTEGER,
            payment_value NUMERIC(12, 2),

            CONSTRAINT pk_order_payments
                PRIMARY KEY (order_id, payment_sequential)
        )
    """,

    "order_reviews": """
        CREATE TABLE public.order_reviews (
            review_id VARCHAR(50) NOT NULL,
            order_id VARCHAR(50) NOT NULL,
            review_score INTEGER,
            review_comment_title VARCHAR(500),
            review_comment_message VARCHAR(4000),
            review_creation_date TIMESTAMP,
            review_answer_timestamp TIMESTAMP,

            CONSTRAINT pk_order_reviews
                PRIMARY KEY (review_id, order_id)
        )
    """,

    "orders": """
        CREATE TABLE public.orders (
            order_id VARCHAR(50) NOT NULL,
            customer_id VARCHAR(50),
            order_status VARCHAR(50),
            order_purchase_timestamp TIMESTAMP,
            order_approved_at TIMESTAMP,
            order_delivered_carrier_date TIMESTAMP,
            order_delivered_customer_date TIMESTAMP,
            order_estimated_delivery_date TIMESTAMP,

            CONSTRAINT pk_orders
                PRIMARY KEY (order_id)
        )
    """,

    "products": """
        CREATE TABLE public.products (
            product_id VARCHAR(50) NOT NULL,
            product_category_name VARCHAR(100),
            product_name_lenght INTEGER,
            product_description_lenght INTEGER,
            product_photos_qty INTEGER,
            product_weight_g INTEGER,
            product_length_cm INTEGER,
            product_height_cm INTEGER,
            product_width_cm INTEGER,

            CONSTRAINT pk_products
                PRIMARY KEY (product_id)
        )
    """,

    "sellers": """
        CREATE TABLE public.sellers (
            seller_id VARCHAR(50) NOT NULL,
            seller_zip_code_prefix INTEGER,
            seller_city VARCHAR(100),
            seller_state VARCHAR(10),

            CONSTRAINT pk_sellers
                PRIMARY KEY (seller_id)
        )
    """,

    "product_category_name_translation": """
        CREATE TABLE public.product_category_name_translation (
            product_category_name VARCHAR(100) NOT NULL,
            product_category_name_english VARCHAR(100),

            CONSTRAINT pk_product_category_translation
                PRIMARY KEY (product_category_name)
        )
    """
}


# ============================================================
# COLUNAS DOS CSVs
# ============================================================

COLUNAS = {

    "customers": [
        "customer_id",
        "customer_unique_id",
        "customer_zip_code_prefix",
        "customer_city",
        "customer_state",
    ],

    "geolocation": [
        "geolocation_zip_code_prefix",
        "geolocation_lat",
        "geolocation_lng",
        "geolocation_city",
        "geolocation_state",
    ],

    "order_items": [
        "order_id",
        "order_item_id",
        "product_id",
        "seller_id",
        "shipping_limit_date",
        "price",
        "freight_value",
    ],

    "order_payments": [
        "order_id",
        "payment_sequential",
        "payment_type",
        "payment_installments",
        "payment_value",
    ],

    "order_reviews": [
        "review_id",
        "order_id",
        "review_score",
        "review_comment_title",
        "review_comment_message",
        "review_creation_date",
        "review_answer_timestamp",
    ],

    "orders": [
        "order_id",
        "customer_id",
        "order_status",
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],

    "products": [
        "product_id",
        "product_category_name",
        "product_name_lenght",
        "product_description_lenght",
        "product_photos_qty",
        "product_weight_g",
        "product_length_cm",
        "product_height_cm",
        "product_width_cm",
    ],

    "sellers": [
        "seller_id",
        "seller_zip_code_prefix",
        "seller_city",
        "seller_state",
    ],

    "product_category_name_translation": [
        "product_category_name",
        "product_category_name_english",
    ],
}


# ============================================================
# BUSCAR CREDENCIAIS DO RDS
# ============================================================

def get_rds_credentials(instance_id):

    rds = boto3.client(
        "rds",
        region_name=AWS_REGION
    )

    db = rds.describe_db_instances(
        DBInstanceIdentifier=instance_id
    )

    instance = db["DBInstances"][0]

    host = instance["Endpoint"]["Address"]
    port = instance["Endpoint"]["Port"]
    database = instance["DBName"]

    secret_arn = instance["MasterUserSecret"]["SecretArn"]

    sm = boto3.client(
        "secretsmanager",
        region_name=AWS_REGION
    )

    secret = json.loads(
        sm.get_secret_value(
            SecretId=secret_arn
        )["SecretString"]
    )

    return (
        host,
        port,
        database,
        secret["username"],
        secret["password"],
    )


# ============================================================
# CONEXÃO
# ============================================================

print("Buscando credenciais do RDS...")

HOST, PORT, DATABASE, USER, PASSWORD = (
    get_rds_credentials(RDS_INSTANCE_ID)
)

print("Testando conexão com o PostgreSQL...")

try:

    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        dbname=DATABASE,
        user=USER,
        password=PASSWORD,
    )

    conn.autocommit = False

    print("Conexão realizada com sucesso!")

except Exception as error:

    print("Erro ao conectar no PostgreSQL:")
    print(error)

    raise


# ============================================================
# CRIAR TABELAS
# ============================================================

cur = conn.cursor()

print()
print("=" * 60)
print("CRIANDO ESTRUTURA DAS TABELAS")
print("=" * 60)

for tabela, create_sql in SCHEMAS.items():

    print(f"Criando tabela: {tabela}")

    # Para a carga inicial do laboratório.
    cur.execute(
        f'DROP TABLE IF EXISTS public."{tabela}" CASCADE'
    )

    cur.execute(create_sql)

conn.commit()

print("Estrutura criada com sucesso!")


# ============================================================
# CARREGAR CSVs
# ============================================================

print()
print("=" * 60)
print("INICIANDO CARGA DOS CSVs")
print("=" * 60)


for arquivo, tabela in ARQUIVOS.items():

    caminho_arquivo = PASTA_CSV / arquivo

    print()
    print("=" * 60)
    print(f"Arquivo : {arquivo}")
    print(f"Tabela  : {tabela}")
    print("=" * 60)

    # --------------------------------------------------------
    # Verificar arquivo
    # --------------------------------------------------------

    if not caminho_arquivo.exists():

        print(
            f"[ERRO] Arquivo não encontrado: "
            f"{caminho_arquivo}"
        )

        conn.rollback()
        continue

    # --------------------------------------------------------
    # Verificar cabeçalho
    # --------------------------------------------------------

    with open(
        caminho_arquivo,
        encoding="utf-8-sig"
    ) as f:

        reader = csv.reader(f)

        colunas_csv = next(reader)

    colunas_esperadas = COLUNAS[tabela]

    if colunas_csv != colunas_esperadas:

        print("[ERRO] Cabeçalho diferente do esperado.")

        print()
        print("Esperado:")
        print(colunas_esperadas)

        print()
        print("Encontrado:")
        print(colunas_csv)

        conn.rollback()

        raise ValueError(
            f"Cabeçalho inesperado no arquivo {arquivo}"
        )

    # --------------------------------------------------------
    # COPY
    # --------------------------------------------------------

    colunas_sql = ", ".join(
        f'"{coluna}"'
        for coluna in colunas_esperadas
    )

    try:

        with open(
            caminho_arquivo,
            encoding="utf-8-sig"
        ) as f:

            cur.copy_expert(
                f"""
                COPY public."{tabela}"
                ({colunas_sql})
                FROM STDIN
                WITH (
                    FORMAT csv,
                    HEADER true,
                    NULL ''
                )
                """,
                f,
            )

        # ----------------------------------------------------
        # Contagem
        # ----------------------------------------------------

        cur.execute(
            f'SELECT COUNT(*) '
            f'FROM public."{tabela}"'
        )

        total = cur.fetchone()[0]

        conn.commit()

        print(
            f"[OK] {tabela} carregada."
        )

        print(
            f"Registros carregados: {total}"
        )

    except Exception as error:

        conn.rollback()

        print(
            f"[ERRO] Falha ao carregar {tabela}"
        )

        print(error)

        raise


# ============================================================
# FECHAR CONEXÃO
# ============================================================

cur.close()
conn.close()


# ============================================================
# FINAL
# ============================================================

print()
print("=" * 60)
print("CARGA DOS ARQUIVOS FINALIZADA!")
print("=" * 60)


# ============================================================
# EXECUÇÃO
# ============================================================
