# MacBook Air — Top-Level Build Guide

## Phase 1 — Verify your Mac

```bash
uname -m
system_profiler SPHardwareDataType | grep Memory
```

`arm64` means Apple Silicon. Docker images used here are multi-platform, but if an image ever fails on ARM, check the image's architecture support before forcing `linux/amd64` emulation.

## Phase 2 — Install tools

Install:
- Docker Desktop for Mac
- Git
- VS Code
- Python 3
- DBeaver Community

Verify:

```bash
docker --version
docker compose version
python3 --version
git --version
```

## Phase 3 — Configure the repository

```bash
cp .env.example .env
```

Replace every `ChangeMe...` value and set a long random `SUPERSET_SECRET_KEY`.

Validate Compose:

```bash
docker compose config
```

## Phase 4 — Start the infrastructure gradually

Start the databases and object store first:

```bash
docker compose up -d mariadb postgres minio minio-init
docker compose ps
```

Endpoints from the Mac host:
- MariaDB: `localhost:3307`, database `source_db`
- PostgreSQL: `localhost:5433`, database from `POSTGRES_DB`
- MinIO API: `http://localhost:9000`
- MinIO Console: `http://localhost:9001`

This gradual start is easier on a MacBook Air than starting every service at once.

## Phase 5 — Generate payment data

Start small:

```bash
python3 scripts/generate_payment_data.py --transactions 10000 --customers 2000 --merchants 200
```

When the project is stable, try 50k, then 100k+ transactions.

Generated files:
- `customers.csv`
- `merchants.csv`
- `payment_methods.csv`
- `payment_transactions.csv`
- `refunds.csv`
- `cancellations.csv`

The generator intentionally adds two DQ scenarios near the end of `payment_transactions.csv`: one negative amount and one unknown merchant.

## Phase 6 — Load CSVs to MariaDB

Use DBeaver's **Import Data → CSV** wizard for each table. Match filenames to same-named tables. Import parent/reference tables first:

```text
customers
merchants
payment_methods
payment_transactions
refunds
cancellations
```

Then run `scripts/mariadb_validation.sql`.

## Phase 7 — Validate the warehouse schema

PostgreSQL initializes `dw` and `control` automatically from `sql/postgres/01-warehouse-schema.sql` on a fresh volume.

Run `scripts/postgres_validation.sql` in DBeaver.

If you previously started an older schema and need a completely fresh lab, only then use:

```bash
docker compose down -v
```

Warning: `-v` deletes the project database/object-storage volumes.

## Phase 8 — Start Apache Hop

```bash
docker compose up -d hop-web
```

Open `http://localhost:8080`.

Create these Hop connections:

### MariaDB source
- Host: `mariadb`
- Port: `3306`
- DB: `source_db`
- Username/password: values from `.env`

### PostgreSQL warehouse
- Host: `postgres`
- Port: `5432`
- DB: `${POSTGRES_DB}`
- Username/password: `${POSTGRES_USER}` / `${POSTGRES_PASSWORD}`

Remember: from **inside Docker**, use service names (`mariadb`, `postgres`), not `localhost`.

## Phase 9 — Build Hop pipelines in this order

1. `dim_date` — populate calendar dates.
2. `dim_merchant` — Type 1 dimension.
3. `dim_payment_method` — Type 1 dimension.
4. `dim_customer_scd2` — SCD Type 2 customer history.
5. `get_payment_watermark` — read last successful timestamp.
6. `get_payment_upper_bound` — capture source max `updated_at` before batch.
7. `raw_payments_to_minio` — land raw source data.
8. `fact_payment_transaction` — incremental fact + DQ routing.
9. `fact_refund` and `fact_cancellation` — related transaction events.
10. `wf_payment_incremental_audit` — orchestrate, audit, and advance watermark only on success.

Exact SQL/logic is in `hop-project/README.md`.

## Phase 10 — DQ rules to implement

Start with four rules:

```text
DQ001 amount must be >= 0
DQ002 merchant must exist
DQ003 customer must exist
DQ004 status must be APPROVED / DECLINED / PENDING
```

Valid rows go to `dw.fact_payment_transaction`.
Invalid rows go to `control.data_quality_rejects` and optionally `MinIO rejects/payments/`.

## Phase 11 — Incremental logic

Use:

```text
updated_at > PAYMENT_WATERMARK
AND updated_at <= PAYMENT_WATERMARK_END
```

Do not update the persisted watermark until the fact pipeline succeeds.

Re-running the same interval must not duplicate `transaction_id` in the fact table.

## Phase 12 — Reconciliation

Create hourly metrics for:

```text
SOURCE
WAREHOUSE
BI
```

Store them in `control.dq_metrics` by date, hour and transaction type. Run `scripts/reconciliation_queries.sql` to find mismatched hours.

## Phase 13 — Superset dashboards

Start Superset:

```bash
docker compose up -d --build superset
```

Open `http://localhost:8088`.

Create a PostgreSQL connection using the `bi_reader` credentials.

Dashboard 1 — **Payment Analytics**:
- Approved payment amount
- Transaction count
- Approval rate
- Average transaction value
- Payment trend by day/month
- Amount by merchant category
- Transactions by payment method
- Declines by merchant/category
- Refund/cancellation rates

Dashboard 2 — **Data Quality & ETL Operations**:
- Last successful ETL run
- Rows read/written/rejected
- Reject rate
- Failed runs
- Average run duration
- Watermark value
- Source vs warehouse hourly count difference
- Warehouse vs BI hourly difference

## Phase 14 — Failure tests

Demonstrate these deliberately:

1. Bad amount is rejected.
2. Unknown merchant is rejected or mapped to Unknown based on your chosen rule.
3. Stop the fact pipeline midway and confirm watermark does not advance.
4. Rerun same interval and confirm no duplicate transaction IDs.
5. Change a customer's risk segment/city and confirm SCD2 old/new versions.
6. Create a controlled source/warehouse count mismatch and find the exact hour with reconciliation SQL.

## Phase 15 — Portfolio explanation

Your interview story should be:

```text
I built a local payments platform using MariaDB as an OLTP source,
Apache Hop for incremental ETL and SCD processing, MinIO as an S3-like
landing zone, PostgreSQL as a star-schema warehouse, control tables for
watermark/audit/DQ/reconciliation, and Superset for business and operational dashboards.
```

Then map each component to AWS services.
