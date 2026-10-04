# Lakehouse de Vendas Olist na AWS

Projeto simulando um Lakehouse de vendas na AWS.

Com o objetivo de construir um lakehouse na AWS com ingestão contínua (CDC),
camadas bronze/silver/gold em Apache Iceberg, modelagem de negócio com dbt,
orquestração diária e controle de acesso por perfil.

## Arquitetura

RDS PostgreSQL → AWS DMS → S3 → EMR/Spark → Apache Iceberg → dbt → Athena

Fonte -	RDS PostgreSQL (db.t4g.micro) com a base Olist + Lambda geradora de pedidos						
Ingestão - AWS DMS: full load + CDC → S3 landing (Parquet)						
Processamento -	EMR (on EC2) com PySpark: landing → bronze (append) → silver (MERGE INTO, estado atual)						
Modelagem -	dbt Core com adapter dbt-athena: silver → gold (agregados de negócio em Iceberg), com testes e documentação						
Armazenamento -	S3 + tabelas Apache Iceberg registradas no Glue Data Catalog						
Consumo -	Amazon Athena (workgroup com limite de dados escaneados)						
Orquestração - Airflow em EC2 (docker-compose), DAG diária com retries e alertas						
Governança - IAM (roles por serviço) + Lake Formation (perfil engenharia vs perfil analista)						
Engenharia - Terraform (state remoto em S3) + Git com Pull Requests						