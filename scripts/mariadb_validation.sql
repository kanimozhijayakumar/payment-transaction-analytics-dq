USE source_db;
SELECT 'customers' table_name,COUNT(*) row_count FROM customers
UNION ALL SELECT 'merchants',COUNT(*) FROM merchants
UNION ALL SELECT 'payment_methods',COUNT(*) FROM payment_methods
UNION ALL SELECT 'payment_transactions',COUNT(*) FROM payment_transactions
UNION ALL SELECT 'refunds',COUNT(*) FROM refunds
UNION ALL SELECT 'cancellations',COUNT(*) FROM cancellations;
SELECT DATE(transaction_ts) txn_date,HOUR(transaction_ts) txn_hour,status,COUNT(*) txn_count,ROUND(SUM(amount),2) amount_total
FROM payment_transactions GROUP BY 1,2,3 ORDER BY 1 DESC,2 DESC,3;
