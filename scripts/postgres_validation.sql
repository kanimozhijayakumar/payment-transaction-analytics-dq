SELECT current_database(),current_user,version();
SELECT table_schema,table_name FROM information_schema.tables WHERE table_schema IN ('dw','control') ORDER BY 1,2;
SELECT 'dim_date' object_name,COUNT(*) row_count FROM dw.dim_date
UNION ALL SELECT 'dim_customer',COUNT(*) FROM dw.dim_customer
UNION ALL SELECT 'dim_merchant',COUNT(*) FROM dw.dim_merchant
UNION ALL SELECT 'dim_payment_method',COUNT(*) FROM dw.dim_payment_method
UNION ALL SELECT 'fact_payment_transaction',COUNT(*) FROM dw.fact_payment_transaction;
SELECT * FROM control.etl_watermark ORDER BY pipeline_name;
SELECT * FROM control.etl_audit ORDER BY audit_id DESC LIMIT 20;
SELECT txn_date,txn_hour,source,txn_type,txn_count,amount_total FROM control.dq_metrics ORDER BY txn_date DESC,txn_hour DESC,source;
