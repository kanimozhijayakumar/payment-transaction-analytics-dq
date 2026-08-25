# Payment Transaction Analytics & Data Quality Platform

A containerized data engineering project that implements an end-to-end payment transaction analytics and data quality platform using **MariaDB, Apache Hop, PostgreSQL, Docker, Python, and Metabase**.

The project demonstrates source-to-warehouse ETL, dimensional modelling, transaction fact and dimension tables, data quality validation, SQL-based reconciliation, and business analytics through interactive dashboards.

> This repository was developed as a local data-engineering project to demonstrate practical ETL, data warehousing, data quality, validation, and analytics engineering concepts.

## Architecture

![Payment Transaction Analytics Platform Architecture](docs/architecture.png)

The platform follows this end-to-end data flow:

````markdown


                  Payment Transaction Analytics Platform

 MariaDB / Source Database
          |
          v
      Apache Hop
 ETL + Transformation
          |
          v
 PostgreSQL Data Warehouse
          |
          v
 Data Quality Validation
          |
          v
       Metabase
 Business + DQ Analytics
````

## Local Technology Mapping

| Local component | Purpose                                           |
| --------------- | ------------------------------------------------- |
| MariaDB         | Source / OLTP transaction database                |
| Apache Hop      | ETL and workflow orchestration                    |
| PostgreSQL      | Analytical data warehouse                         |
| Docker Compose  | Containerized local development environment       |
| Metabase        | Business intelligence and data-quality dashboards |
| Python          | Supporting data generation and project utilities  |
| SQL             | Transformation, validation, and reconciliation    |
| Git / GitHub    | Version control and project documentation         |

## What I Implemented

### Warehouse Modeling

The project uses a dimensional modelling approach for payment transaction analytics.

Implemented warehouse components include:

* `dim_date` pipeline
* `dim_payment_method` pipeline
* Payment transaction fact processing
* Surrogate-key based dimensional lookups
* Transaction-level analytical measures
* PostgreSQL warehouse schema

The overall warehouse design follows:

```text
                    dim_date
                       |
                       |
                       v
dim_payment_method ---> fact_payment_transaction
                       ^
                       |
                       |
                 Other Dimensions
```

The fact table stores transaction-level records and connects them with the appropriate dimension attributes for analytical reporting.

### Source-to-Warehouse ETL

Apache Hop is used to extract payment transaction data from MariaDB, transform the source records, validate the data, and load the processed records into PostgreSQL.

The ETL flow follows:

```text
MariaDB Source
      |
      v
Source Extraction
      |
      v
Transformation
      |
      v
Data Validation
      |
      v
Dimension Lookups
      |
      v
PostgreSQL Warehouse
```

This separates the operational source system from the analytical warehouse and provides a structured foundation for reporting.

## Reliable ETL Processing

The ETL process is designed around controlled source extraction and warehouse loading.

The processing flow is:

```text
Source Data
    |
    v
Apache Hop
    |
    +---- Extract
    |
    +---- Transform
    |
    +---- Validate
    |
    +---- Lookup
    |
    +---- Load
    |
    v
PostgreSQL Data Warehouse
```

Apache Hop pipelines are used to make the transformation and loading process repeatable and easier to maintain.

## Data Quality and Validation

Data quality is a core part of the project.

The payment transaction data is validated before being used for analytical reporting.

Validation checks include:

* Null transaction ID checks
* Duplicate transaction ID checks
* Invalid transaction amount checks
* Invalid transaction status checks
* Missing dimension-key checks
* Transaction count reconciliation
* Source-to-warehouse validation

### Transaction ID Validation

Transaction IDs should not be NULL.

Example validation:

```sql
SELECT COUNT(*) AS null_transaction_ids
FROM dw.fact_payment_transaction
WHERE transaction_id IS NULL;
```

### Duplicate Transaction Validation

Duplicate transaction IDs are checked to identify potential duplicate fact records.

```sql
SELECT
    transaction_id,
    COUNT(*) AS duplicate_count
FROM dw.fact_payment_transaction
GROUP BY transaction_id
HAVING COUNT(*) > 1;
```

### Data Quality Workflow

```text
Payment Transaction Source
          |
          v
      Apache Hop
          |
          v
    Data Validation
       /       \
      /         \
 Valid Records   Invalid Records
      |               |
      v               v
 PostgreSQL       Validation /
 Warehouse        Reconciliation
      |
      v
   Metabase
```

## Validation Performed

The implementation was validated using SQL queries, ETL execution, and Metabase dashboard results.

| Test                             | Result           |
| -------------------------------- | ---------------- |
| Source transaction extraction    | Completed        |
| Warehouse transaction loading    | Completed        |
| Null transaction ID validation   | Performed        |
| Duplicate transaction validation | Performed        |
| Payment amount validation        | Performed        |
| Transaction status validation    | Performed        |
| Dimension-key validation         | Performed        |
| Dashboard validation             | Completed        |
| Total transaction reconciliation | 998 transactions |

The current analytical dashboard contains:

**998 total transactions**

The validation process is intended to confirm that the data loaded into the analytical warehouse can be safely consumed by the reporting layer.

## Business Dashboard

A dedicated Metabase dashboard was created for payment transaction analytics.

The dashboard provides business-oriented visibility into payment activity.

It includes metrics and visualizations such as:

* Total Transactions
* Total Payment Amount
* Transaction Status
* Payment Method
* Merchant Transactions
* Monthly Transaction Trend
* Payment transaction summaries

![Payment Transaction Analytics Dashboard](docs/Payment%20Transaction%20Analytics%20Dashboard.png)

The dashboard provides a business-facing view of the payment transaction warehouse.

> Dashboard values are generated from project data and are intended to demonstrate the engineering and analytics workflow rather than represent real business performance.

## ETL / Data Quality Dashboard

A separate Metabase dashboard was created to monitor payment transaction data quality.

The dashboard is designed to expose data-quality issues and validation results.

It includes areas such as:

* Total Transactions
* Data quality checks
* Null transaction validation
* Duplicate transaction validation
* Transaction validation metrics
* Payment transaction quality indicators

![Payment Transaction Data Quality Dashboard](docs/Payment%20Transaction%20Data%20Quality%20Dashboard.png)

The Data Quality dashboard provides an operational view of the warehouse data before it is used for business reporting.

## Apache Hop Assets

Apache Hop is used as the primary ETL and transformation platform.

The Hop project contains pipeline and workflow assets used to process the payment transaction data.

```text
hop-project/
├── pipelines/
│   ├── dim_date.hpl
│   ├── dim_payment_method.hpl
│   └── ...
│
└── workflows/
    └── ...
```

The pipelines cover source extraction, transformation, validation, dimension processing, and warehouse loading.

The Hop project is maintained separately from the database and dashboard layers so that the ETL logic remains modular and reusable.

## Data Warehouse

The PostgreSQL database acts as the analytical warehouse.

The warehouse separates analytical data from the MariaDB operational source system.

The overall flow is:

```text
MariaDB
   |
   | Source Data
   v
Apache Hop
   |
   | Transformed Data
   v
PostgreSQL
   |
   | Analytical Data
   v
Metabase
```

### Fact Table

`dw.fact_payment_transaction`

The fact table contains payment transaction-level data used for analytical reporting.

It provides the foundation for:

* Transaction counts
* Payment amount analysis
* Status analysis
* Payment method analysis
* Merchant analysis
* Time-based transaction analysis

### Dimension Tables

`dw.dim_date`

Provides date-related attributes used for time-based reporting.

`dw.dim_payment_method`

Provides payment method attributes used to categorize and analyze transactions.

Additional dimensions can be added as the warehouse model is extended.

## Repository Structure

```text
payment-transaction-analytics-dq/
│
├── datasets/
│   ├── generated/
│   │   ├── cancellations.csv
│   │   ├── customers.csv
│   │   ├── merchants.csv
│   │   ├── payment_methods.csv
│   │   ├── payment_transactions.csv
│   │   └── refunds.csv
│   │
│   └── README.md
│
├── docs/
│   ├── MACBOOK_TOP_LEVEL_GUIDE.md
│   ├── architecture.png
│   ├── Payment Transaction Analytics Dashboard.png
│   └── Payment Transaction Data Quality Dashboard.png
│
├── drivers/
│   └── README.md
│
├── hop-project/
│   ├── pipelines/
│   ├── workflows/
│   └── README.md
│
├── scripts/
│   ├── generate_payment_data.py
│   ├── mariadb_validation.sql
│   ├── postgres_validation.sql
│   └── reconciliation_queries.sql
│
├── sql/
│   ├── mariadb/
│   │   └── 01-source-schema.sql
│   │
│   └── postgres/
│       └── 01-warehouse-schema.sql
│
├── superset/
│   └── Dockerfile
│
├── docker-compose.yml
├── .gitignore
├── LICENSE
└── README.md
```

## Run Locally

### Clone the Repository

```bash
git clone https://github.com/kanimozhijayakumar/payment-transaction-analytics-dq.git
```

### Navigate to the Project

```bash
cd payment-transaction-analytics-dq
```

### Start the Docker Environment

```bash
docker compose up -d
```

### Check Running Containers

```bash
docker compose ps
```

The project uses Docker to provide a consistent local environment for the database and analytics services.

## Local Services

| Service    | Purpose                               |
| ---------- | ------------------------------------- |
| MariaDB    | Source transaction database           |
| PostgreSQL | Analytical data warehouse             |
| Apache Hop | ETL and transformation                |
| Metabase   | Analytics and data-quality dashboards |
| Docker     | Containerized service environment     |

### Metabase

Metabase is used as the business intelligence layer.

Default local URL:

```text
http://localhost:3000
```

The Metabase dashboards provide both business analytics and data-quality monitoring.

## End-to-End Processing Flow

The complete project workflow is:

```text
                    PAYMENT TRANSACTION DATA PLATFORM

                         MariaDB
                     Source Database
                           |
                           |
                           v
                    Apache Hop ETL
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Transformation              Data Validation
             |                           |
             |                           |
             +-------------+-------------+
                           |
                           v
                 PostgreSQL Warehouse
                           |
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Business Analytics          Data Quality
             |                           |
             v                           v
         Metabase                   Metabase
         Dashboard                 Dashboard
```

## Project Results

The completed project demonstrates:

* End-to-end source-to-warehouse ETL
* MariaDB source integration
* PostgreSQL analytical warehouse
* Apache Hop pipeline development
* Dimensional modelling
* Fact and dimension table design
* Data quality validation
* SQL reconciliation
* Payment transaction analytics
* Metabase dashboard development
* Docker-based local environment
* Python-based data generation
* GitHub-based project documentation

The current analytical dataset contains:

```text
998 payment transactions
```

The data is processed from the source database through Apache Hop and made available in PostgreSQL for analytical consumption.

## Security

Sensitive credentials should not be committed to GitHub.

The project uses `.gitignore` rules for local environment and credential-related files.

Before sharing or deploying the project, review:

* Database passwords
* API tokens
* Environment variables
* Local configuration
* Connection credentials
* Docker environment settings

Example credentials used for local development should always be replaced before deployment.

## Skills Demonstrated

`Data Engineering` · `ETL/ELT` · `Apache Hop` · `PostgreSQL` · `MariaDB` · `Docker` · `Metabase` · `Dimensional Modeling` · `Fact Tables` · `Dimension Tables` · `Data Quality` · `Data Validation` · `SQL` · `Python` · `Git` · `GitHub`

## Next Extensions

Possible future extensions for the platform include:

* Automated ETL workflow orchestration
* ETL audit logging
* Automated data-quality quarantine
* Incremental transaction loading
* Watermark-based processing
* Automated failure handling
* Scheduled ETL execution
* Additional business KPIs
* Pipeline monitoring
* Automated data-quality tests
* Larger-scale transaction testing
* Cloud deployment

These are intentionally presented as **next steps**, not as completed functionality.

## Documentation

Additional project documentation is available in the `docs/` directory.

Useful project resources include:

* [MacBook Top-Level Guide](docs/MACBOOK_TOP_LEVEL_GUIDE.md)
* [Datasets Documentation](datasets/README.md)
* [Apache Hop Documentation](hop-project/README.md)
* [Driver Documentation](drivers/README.md)
* SQL validation scripts under `scripts/`
* Database schema scripts under `sql/`

## License

MIT — see [LICENSE](LICENSE).

````


