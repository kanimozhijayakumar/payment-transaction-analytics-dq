# Apache Hop — Payment Domain Pipeline Blueprint

The base project had retail-specific Hop pipelines. This converted project deliberately gives you the **payment-specific pipeline contract and SQL** so you build the transforms in Hop Web and understand them rather than importing opaque XML that may contain machine-specific metadata.

## Connections

Create:
- `lab_source_mariadb` → host `mariadb`, port `3306`, db `source_db`
- `lab_dw_postgres` → host `postgres`, port `5432`, db `warehouse`
- `lablake` → S3-compatible/MinIO endpoint `http://minio:9000`

## 1. dim_date

Use the included `pipelines/dim_date.hpl`. Populate enough dates to cover 2025–2027.

## 2. dim_merchant

**Table Input (MariaDB):**

```sql
SELECT merchant_id, merchant_name, merchant_category, country_code, status
FROM source_db.merchants;
```

**Target:** `dw.dim_merchant`

Use insert/update by `merchant_id`.

## 3. dim_payment_method

```sql
SELECT payment_method_id, method_code, method_group, active_flag
FROM source_db.payment_methods;
```

Target `dw.dim_payment_method`, keyed by `payment_method_id`.

## 4. dim_customer_scd2

Read:

```sql
SELECT customer_id, customer_name, city, state_code, risk_segment, updated_at
FROM source_db.customers;
```

Track changes in `customer_name`, `city`, `state_code`, and `risk_segment`.

For changed rows:
1. expire existing current version (`effective_to = updated_at`, `is_current=false`)
2. insert new version (`effective_from=updated_at`, `effective_to=NULL`, `is_current=true`)

Use a hash of tracked attributes to avoid writing unchanged versions.

## 5. get_payment_watermark

```sql
SELECT last_success_ts
FROM control.etl_watermark
WHERE pipeline_name='payment_transaction_incremental';
```

Set workflow variable `PAYMENT_WATERMARK`.

## 6. get_payment_upper_bound

Capture the maximum source timestamp at batch start:

```sql
SELECT COALESCE(MAX(updated_at), TIMESTAMP('1900-01-01 00:00:00')) AS watermark_end
FROM source_db.payment_transactions;
```

Set `PAYMENT_WATERMARK_END`.

## 7. raw_payments_to_minio

Read:

```sql
SELECT transaction_id, customer_id, merchant_id, payment_method_id,
       transaction_ts, transaction_type, status, currency_code,
       amount, processing_fee, authorization_code, source_system, updated_at
FROM source_db.payment_transactions
WHERE updated_at > '${PAYMENT_WATERMARK}'
  AND updated_at <= '${PAYMENT_WATERMARK_END}';
```

Write CSV/Parquet-style raw landing path such as:

```text
lablake:///raw/payments/payment_transactions_raw.csv
```

## 8. fact_payment_transaction

### Source

Use the same bounded query as raw ingestion.

### DQ split

Route to reject when any applies:
- `amount < 0` → `DQ001_NEGATIVE_AMOUNT`
- merchant lookup missing → `DQ002_UNKNOWN_MERCHANT`
- customer lookup missing → `DQ003_UNKNOWN_CUSTOMER`
- status not in `APPROVED, DECLINED, PENDING` → `DQ004_BAD_STATUS`

### Dimension lookups

Merchant:

```sql
SELECT merchant_key FROM dw.dim_merchant WHERE merchant_id=?;
```

Payment method:

```sql
SELECT payment_method_key FROM dw.dim_payment_method WHERE payment_method_id=?;
```

Customer as-of transaction timestamp:

```sql
SELECT customer_key
FROM dw.dim_customer
WHERE customer_id=?
  AND ? >= effective_from
  AND (effective_to IS NULL OR ? < effective_to)
ORDER BY effective_from DESC
LIMIT 1;
```

### Derived field

```text
net_amount = amount - processing_fee
```

### Target

`dw.fact_payment_transaction`. Use `transaction_id` as the natural idempotency key; do not create duplicates on rerun.

### Reject target

Write rejected rows to `control.data_quality_rejects` with `pipeline_name='fact_payment_transaction'` and also optionally to `lablake:///rejects/payments/`.

## 9. refunds

Read incremental refunds by `updated_at`; validate refund amount > 0 and optionally validate the original transaction exists. Load to `dw.fact_refund` keyed by `refund_id`.

## 10. cancellations

Read incremental cancellations by `updated_at`; validate the original transaction exists. Load to `dw.fact_cancellation` keyed by `cancellation_id`.

## 11. wf_payment_incremental_audit

Recommended order:

```text
START
  -> insert RUNNING audit row
  -> get PAYMENT_WATERMARK
  -> get PAYMENT_WATERMARK_END
  -> raw_payments_to_minio
  -> dim_customer_scd2 / dims (as needed)
  -> fact_payment_transaction
  -> refunds/cancellations
  -> collect row/reject counts
  -> update audit SUCCESS
  -> advance control.etl_watermark to PAYMENT_WATERMARK_END
END
```

On any failure:

```text
update audit FAILED
DO NOT advance watermark
```

That failure-safe ordering is one of the most important concepts in the project.
