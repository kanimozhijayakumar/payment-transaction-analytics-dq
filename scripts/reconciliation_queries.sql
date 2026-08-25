-- Warehouse hourly payment totals
SELECT d.full_date AS txn_date,EXTRACT(HOUR FROM f.transaction_ts)::int AS txn_hour,
       COUNT(*) AS txn_count,ROUND(SUM(f.amount),2) AS amount_total
FROM dw.fact_payment_transaction f JOIN dw.dim_date d ON d.date_key=f.date_key
GROUP BY 1,2 ORDER BY 1,2;

-- Compare recorded DQ metrics between HARVEST-style source, NEXUS-style warehouse, and BI layer.
SELECT txn_date,txn_hour,txn_type,
       MAX(txn_count) FILTER (WHERE source='SOURCE') AS source_cnt,
       MAX(txn_count) FILTER (WHERE source='WAREHOUSE') AS warehouse_cnt,
       MAX(txn_count) FILTER (WHERE source='BI') AS bi_cnt,
       COALESCE(MAX(txn_count) FILTER (WHERE source='SOURCE'),0)-COALESCE(MAX(txn_count) FILTER (WHERE source='WAREHOUSE'),0) AS source_warehouse_diff,
       COALESCE(MAX(txn_count) FILTER (WHERE source='WAREHOUSE'),0)-COALESCE(MAX(txn_count) FILTER (WHERE source='BI'),0) AS warehouse_bi_diff
FROM control.dq_metrics GROUP BY txn_date,txn_hour,txn_type ORDER BY txn_date,txn_hour,txn_type;
