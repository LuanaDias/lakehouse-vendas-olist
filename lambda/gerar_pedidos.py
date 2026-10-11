import json
import os
import random
import string
import uuid
from datetime import datetime, timedelta

import boto3
import psycopg2


def get_credentials():
    client = boto3.client("secretsmanager")
    secret = client.get_secret_value(SecretId=os.environ["RDS_SECRET_ARN"])
    return json.loads(secret["SecretString"])


def get_connection():
    creds = get_credentials()
    return psycopg2.connect(
        host=os.environ["RDS_ENDPOINT"],
        port=os.environ["RDS_PORT"],
        dbname=os.environ["RDS_DATABASE"],
        user=creds["username"],
        password=creds["password"],
        sslmode="require",
    )


def random_id(length=32):
    return "".join(random.choices(string.hexdigits[:16], k=length))


def random_zip():
    return f"{random.randint(10000, 99999)}"


ESTADOS = ["SP", "RJ", "MG", "RS", "PR", "SC", "BA", "CE", "PE", "GO"]
CIDADES = [
    "sao paulo", "rio de janeiro", "belo horizonte", "porto alegre",
    "curitiba", "florianopolis", "salvador", "fortaleza", "recife", "goiania",
]
STATUS_FLOW = [
    "created", "approved", "invoiced", "processing",
    "shipped", "delivered",
]
CATEGORIAS = [
    "informatica_acessorios", "telefonia", "eletronicos",
    "moveis_decoracao", "beleza_saude", "esporte_lazer",
    "utilidades_domesticas", "brinquedos", "ferramentas_jardim",
]
PAGAMENTOS = ["credit_card", "boleto", "voucher", "debit_card"]


def gerar_novos_pedidos(cur, quantidade=3):
    pedidos_criados = 0

    for _ in range(quantidade):
        order_id = random_id()
        customer_id = random_id()
        seller_id = random_id()
        product_id = random_id()

        estado = random.choice(ESTADOS)
        cidade = random.choice(CIDADES)
        now = datetime.utcnow()
        purchase = now - timedelta(minutes=random.randint(1, 60))

        cur.execute(
            """
            INSERT INTO customers
            (customer_id, customer_unique_id, customer_zip_code_prefix,
             customer_city, customer_state)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (customer_id, random_id(), random_zip(), cidade, estado),
        )

        cur.execute(
            """
            INSERT INTO sellers
            (seller_id, seller_zip_code_prefix, seller_city, seller_state)
            VALUES (%s, %s, %s, %s)
            """,
            (seller_id, random_zip(), random.choice(CIDADES), random.choice(ESTADOS)),
        )

        cur.execute(
            """
            INSERT INTO products
            (product_id, product_category_name,
             product_name_lenght, product_description_lenght,
             product_photos_qty, product_weight_g,
             product_length_cm, product_height_cm, product_width_cm)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                product_id, random.choice(CATEGORIAS),
                str(random.randint(10, 80)), str(random.randint(50, 500)),
                str(random.randint(1, 6)), str(random.randint(100, 30000)),
                str(random.randint(10, 100)), str(random.randint(5, 50)),
                str(random.randint(10, 80)),
            ),
        )

        cur.execute(
            """
            INSERT INTO orders
            (order_id, customer_id, order_status,
             order_purchase_timestamp, order_approved_at)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (order_id, customer_id, "created",
             purchase.isoformat(), now.isoformat()),
        )

        preco = round(random.uniform(15, 500), 2)
        frete = round(random.uniform(5, 50), 2)

        cur.execute(
            """
            INSERT INTO order_items
            (order_id, order_item_id, product_id, seller_id,
             shipping_limit_date, price, freight_value)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                order_id, "1", product_id, seller_id,
                (now + timedelta(days=7)).isoformat(),
                str(preco), str(frete),
            ),
        )

        cur.execute(
            """
            INSERT INTO order_payments
            (order_id, payment_sequential, payment_type,
             payment_installments, payment_value)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                order_id, "1", random.choice(PAGAMENTOS),
                str(random.randint(1, 12)), str(preco + frete),
            ),
        )

        pedidos_criados += 1

    return pedidos_criados


def atualizar_status(cur, quantidade=5):
    cur.execute(
        """
        SELECT order_id, order_status FROM orders
        WHERE order_status != 'delivered'
        ORDER BY random()
        LIMIT %s
        """,
        (quantidade,),
    )

    pedidos = cur.fetchall()
    atualizados = 0
    now = datetime.utcnow()

    for order_id, status_atual in pedidos:
        if status_atual not in STATUS_FLOW:
            continue

        idx = STATUS_FLOW.index(status_atual)
        if idx >= len(STATUS_FLOW) - 1:
            continue

        novo_status = STATUS_FLOW[idx + 1]

        update_fields = {"order_status": novo_status}

        if novo_status == "shipped":
            update_fields["order_delivered_carrier_date"] = now.isoformat()
        elif novo_status == "delivered":
            update_fields["order_delivered_customer_date"] = now.isoformat()

        set_clause = ", ".join(f"{k} = %s" for k in update_fields)
        values = list(update_fields.values()) + [order_id]

        cur.execute(
            f"UPDATE orders SET {set_clause} WHERE order_id = %s",
            values,
        )
        atualizados += 1

    return atualizados


def handler(event, context):
    conn = get_connection()
    cur = conn.cursor()

    try:
        novos = gerar_novos_pedidos(cur, quantidade=3)
        atualizados = atualizar_status(cur, quantidade=5)
        conn.commit()

        resultado = {
            "pedidos_criados": novos,
            "status_atualizados": atualizados,
            "timestamp": datetime.utcnow().isoformat(),
        }

        print(json.dumps(resultado))
        return resultado

    except Exception as e:
        conn.rollback()
        print(f"Erro: {e}")
        raise

    finally:
        cur.close()
        conn.close()
