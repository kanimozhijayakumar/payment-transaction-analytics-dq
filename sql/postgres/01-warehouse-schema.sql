BEGIN;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS control;

CREATE TABLE IF NOT EXISTS dw.dim_date (
  date_key integer PRIMARY KEY,
  full_date date NOT NULL UNIQUE,
  year_num smallint NOT NULL,
  quarter_num smallint NOT NULL CHECK (quarter_num BETWEEN 1 AND 4),
  month_num smallint NOT NULL CHECK (month_num BETWEEN 1 AND 12),
  month_name varchar(12) NOT NULL,
  day_num smallint NOT NULL CHECK (day_num BETWEEN 1 AND 31),
  day_name varchar(12) NOT NULL,
  is_weekend boolean NOT NULL
);

CREATE TABLE IF NOT EXISTS dw.dim_customer (
  customer_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL,
  customer_name varchar(120),
  city varchar(80),
  state_code varchar(20),
  risk_segment varchar(20),
  effective_from timestamp NOT NULL,
  effective_to timestamp,
  is_current boolean NOT NULL DEFAULT true,
  row_hash varchar(64),
  UNIQUE (customer_id, effective_from)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_dim_customer_current ON dw.dim_customer(customer_id) WHERE is_current=true;

CREATE TABLE IF NOT EXISTS dw.dim_merchant (
  merchant_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  merchant_id bigint NOT NULL UNIQUE,
  merchant_name varchar(160),
  merchant_category varchar(80),
  country_code char(2),
  status varchar(20),
  load_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dw.dim_payment_method (
  payment_method_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payment_method_id bigint NOT NULL UNIQUE,
  method_code varchar(30),
  method_group varchar(30),
  active_flag char(1),
  load_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dw.fact_payment_transaction (
  payment_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  transaction_id bigint NOT NULL UNIQUE,
  date_key integer NOT NULL REFERENCES dw.dim_date(date_key),
  customer_key bigint NOT NULL REFERENCES dw.dim_customer(customer_key),
  merchant_key bigint NOT NULL REFERENCES dw.dim_merchant(merchant_key),
  payment_method_key bigint NOT NULL REFERENCES dw.dim_payment_method(payment_method_key),
  transaction_ts timestamp NOT NULL,
  transaction_type varchar(20) NOT NULL,
  status varchar(20) NOT NULL,
  currency_code char(3) NOT NULL,
  amount numeric(14,2) NOT NULL,
  processing_fee numeric(14,2) NOT NULL DEFAULT 0,
  net_amount numeric(14,2) NOT NULL,
  authorization_code varchar(40),
  source_system varchar(30),
  source_updated_at timestamp,
  load_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (amount >= 0),
  CHECK (processing_fee >= 0)
);
CREATE INDEX IF NOT EXISTS ix_fact_payment_date ON dw.fact_payment_transaction(date_key);
CREATE INDEX IF NOT EXISTS ix_fact_payment_customer ON dw.fact_payment_transaction(customer_key);
CREATE INDEX IF NOT EXISTS ix_fact_payment_merchant ON dw.fact_payment_transaction(merchant_key);
CREATE INDEX IF NOT EXISTS ix_fact_payment_status ON dw.fact_payment_transaction(status);

CREATE TABLE IF NOT EXISTS dw.fact_refund (
  refund_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  refund_id bigint NOT NULL UNIQUE,
  original_transaction_id bigint NOT NULL,
  refund_ts timestamp NOT NULL,
  refund_amount numeric(14,2) NOT NULL CHECK (refund_amount > 0),
  reason_code varchar(40),
  status varchar(20),
  load_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dw.fact_cancellation (
  cancellation_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  cancellation_id bigint NOT NULL UNIQUE,
  original_transaction_id bigint NOT NULL,
  cancellation_ts timestamp NOT NULL,
  reason_code varchar(40),
  load_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS control.etl_watermark (
  pipeline_name varchar(120) PRIMARY KEY,
  last_success_ts timestamp NOT NULL,
  updated_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS control.etl_audit (
  audit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  batch_id varchar(80), pipeline_name varchar(120) NOT NULL,
  run_start_ts timestamp NOT NULL, run_end_ts timestamp,
  status varchar(20) NOT NULL,
  rows_read bigint NOT NULL DEFAULT 0, rows_written bigint NOT NULL DEFAULT 0,
  rows_rejected bigint NOT NULL DEFAULT 0,
  watermark_before timestamp, watermark_after timestamp, message text,
  CHECK (status IN ('RUNNING','SUCCESS','FAILED','WARNING'))
);

CREATE TABLE IF NOT EXISTS control.data_quality_rejects (
  reject_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  batch_id varchar(80), pipeline_name varchar(120) NOT NULL,
  source_entity varchar(80), source_key varchar(160),
  rule_name varchar(160) NOT NULL, rejection_reason text,
  rejected_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS control.dq_metrics (
  metric_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  txn_date date NOT NULL, txn_hour smallint NOT NULL CHECK (txn_hour BETWEEN 0 AND 23),
  source varchar(30) NOT NULL, txn_type varchar(20) NOT NULL,
  txn_count bigint NOT NULL, amount_total numeric(18,2),
  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(txn_date, txn_hour, source, txn_type)
);

INSERT INTO dw.dim_customer(customer_id,customer_name,city,state_code,risk_segment,effective_from,effective_to,is_current,row_hash)
SELECT -1,'Unknown Customer',NULL,NULL,'UNKNOWN',TIMESTAMP '1900-01-01',NULL,true,'UNKNOWN'
WHERE NOT EXISTS (SELECT 1 FROM dw.dim_customer WHERE customer_id=-1);
INSERT INTO dw.dim_merchant(merchant_id,merchant_name,merchant_category,country_code,status)
SELECT -1,'Unknown Merchant','Unknown','US','UNKNOWN' WHERE NOT EXISTS (SELECT 1 FROM dw.dim_merchant WHERE merchant_id=-1);
INSERT INTO dw.dim_payment_method(payment_method_id,method_code,method_group,active_flag)
SELECT -1,'UNKNOWN','UNKNOWN','Y' WHERE NOT EXISTS (SELECT 1 FROM dw.dim_payment_method WHERE payment_method_id=-1);
INSERT INTO control.etl_watermark(pipeline_name,last_success_ts)
VALUES ('payment_transaction_incremental',TIMESTAMP '1900-01-01') ON CONFLICT DO NOTHING;

CREATE OR REPLACE VIEW dw.v_payment_detail AS
SELECT f.payment_key,f.transaction_id,f.transaction_ts,d.full_date,d.year_num,d.month_num,d.month_name,
       c.customer_id,c.customer_name,c.city,c.state_code,c.risk_segment,
       m.merchant_id,m.merchant_name,m.merchant_category,m.country_code,
       pm.method_code,pm.method_group,f.transaction_type,f.status,f.currency_code,
       f.amount,f.processing_fee,f.net_amount,f.source_system,f.load_ts
FROM dw.fact_payment_transaction f
JOIN dw.dim_date d ON d.date_key=f.date_key
JOIN dw.dim_customer c ON c.customer_key=f.customer_key
JOIN dw.dim_merchant m ON m.merchant_key=f.merchant_key
JOIN dw.dim_payment_method pm ON pm.payment_method_key=f.payment_method_key;

CREATE OR REPLACE VIEW control.v_etl_health AS
SELECT pipeline_name,COUNT(*) run_count,
       COUNT(*) FILTER (WHERE status='SUCCESS') success_count,
       COUNT(*) FILTER (WHERE status='FAILED') failed_count,
       SUM(rows_read) rows_read,SUM(rows_written) rows_written,SUM(rows_rejected) rows_rejected,
       MAX(run_end_ts) FILTER (WHERE status='SUCCESS') last_success_ts,
       ROUND(AVG(EXTRACT(EPOCH FROM (run_end_ts-run_start_ts)))::numeric,2) avg_duration_seconds
FROM control.etl_audit GROUP BY pipeline_name;
COMMIT;
