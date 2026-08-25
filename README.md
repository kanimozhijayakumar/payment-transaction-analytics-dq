# Payment Transaction Analytics & Data Quality Platform

A Mac-friendly end-to-end data engineering portfolio project built from the same technical pattern as the retail lab, but redesigned around the **payments domain**.

## Architecture

```text
Synthetic CSV/Python
        |
        v
MariaDB source_db
 customers / merchants / payment_methods
 payment_transactions / refunds / cancellations
        |
        | Apache Hop ETL
        +---------------------------> MinIO
        |                             raw/payments
        v                             curated/payments
PostgreSQL warehouse                  rejects/payments
 dw.dim_date
 dw.dim_customer (SCD2)
 dw.dim_merchant
 dw.dim_payment_method
 dw.fact_payment_transaction
 dw.fact_refund / fact_cancellation
        |
        +--> control.etl_watermark
        +--> control.etl_audit
        +--> control.data_quality_rejects
        +--> control.dq_metrics
        |
        v
Apache Superset
 Payment Analytics + DQ/Reconciliation dashboards
```

## Engineering concepts demonstrated

- Containerized source, data lake, warehouse, ETL and BI
- Dimensional/star-schema modeling
- Customer SCD Type 2
- Incremental watermark loading with captured upper bound
- Idempotent transaction loading using `transaction_id`
- Data-quality quarantine (negative amount, orphan dimensions, bad status/currency)
- ETL audit logging and failure-safe watermark advancement
- Hourly count/amount reconciliation across source, warehouse and BI
- Refund and cancellation analytics

## Local-to-AWS mapping

| Local | AWS concept |
|---|---|
| MariaDB | Amazon RDS / Aurora |
| Apache Hop | AWS Glue / Step Functions-style orchestration |
| MinIO | Amazon S3 |
| PostgreSQL | Amazon Redshift-style warehouse concepts |
| Superset | Amazon QuickSight |
| `control.*` | Glue/CloudWatch/control-table observability patterns |

## Repository

```text
.
├── docker-compose.yml
├── .env.example
├── sql/
│   ├── mariadb/01-source-schema.sql
│   └── postgres/01-warehouse-schema.sql
├── scripts/
│   ├── generate_payment_data.py
│   ├── mariadb_validation.sql
│   ├── postgres_validation.sql
│   └── reconciliation_queries.sql
├── hop-project/
│   ├── README.md
│   ├── pipelines/
│   └── workflows/
├── datasets/
├── docs/
└── superset/
```

## Recommended first run on a MacBook Air

1. Install Docker Desktop, Git, VS Code, Python 3 and DBeaver.
2. Copy `.env.example` to `.env` and replace example passwords.
3. Start only MariaDB, PostgreSQL and MinIO first: `docker compose up -d mariadb postgres minio minio-init`.
4. Generate a small dataset: `python3 scripts/generate_payment_data.py --transactions 10000`.
5. Import the generated CSVs into MariaDB using DBeaver.
6. Validate source counts with `scripts/mariadb_validation.sql`.
7. Start Hop Web and configure the MariaDB/PostgreSQL/MinIO connections.
8. Build/run dimensions first, then the payment fact incremental pipeline.
9. Start Superset and build the two dashboards.

See **`docs/MACBOOK_TOP_LEVEL_GUIDE.md`** for the guided sequence and **`hop-project/README.md`** for pipeline specifications.

## Important note about Hop assets

`dim_date.hpl` is retained from the base lab because it is domain-neutral. The payment-specific Hop jobs are intentionally specified as implementation blueprints in `hop-project/README.md` rather than pretending that environment-specific connection metadata is portable. Build them in Hop Web following the supplied SQL and transformation order; this is also the best way to learn and explain the project in an interview.
