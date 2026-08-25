USE source_db;

CREATE TABLE IF NOT EXISTS customers (
  customer_id BIGINT PRIMARY KEY,
  customer_name VARCHAR(120) NOT NULL,
  email VARCHAR(160),
  city VARCHAR(80),
  state_code VARCHAR(20),
  risk_segment VARCHAR(20) NOT NULL DEFAULT 'STANDARD',
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_customers_updated (updated_at)
);

CREATE TABLE IF NOT EXISTS merchants (
  merchant_id BIGINT PRIMARY KEY,
  merchant_name VARCHAR(160) NOT NULL,
  merchant_category VARCHAR(80) NOT NULL,
  country_code CHAR(2) NOT NULL,
  status VARCHAR(20) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_merchants_updated (updated_at)
);

CREATE TABLE IF NOT EXISTS payment_methods (
  payment_method_id BIGINT PRIMARY KEY,
  method_code VARCHAR(30) NOT NULL UNIQUE,
  method_group VARCHAR(30) NOT NULL,
  active_flag CHAR(1) NOT NULL DEFAULT 'Y',
  updated_at DATETIME(6) NOT NULL
);

CREATE TABLE IF NOT EXISTS payment_transactions (
  transaction_id BIGINT PRIMARY KEY,
  customer_id BIGINT NOT NULL,
  merchant_id BIGINT NOT NULL,
  payment_method_id BIGINT NOT NULL,
  transaction_ts DATETIME(6) NOT NULL,
  transaction_type VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL,
  currency_code CHAR(3) NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  processing_fee DECIMAL(14,2) NOT NULL DEFAULT 0,
  authorization_code VARCHAR(40),
  source_system VARCHAR(30) NOT NULL DEFAULT 'PAYMENTS_APP',
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_txn_updated (updated_at),
  INDEX idx_txn_customer (customer_id),
  INDEX idx_txn_merchant (merchant_id),
  INDEX idx_txn_ts (transaction_ts)
);

CREATE TABLE IF NOT EXISTS refunds (
  refund_id BIGINT PRIMARY KEY,
  original_transaction_id BIGINT NOT NULL,
  refund_ts DATETIME(6) NOT NULL,
  refund_amount DECIMAL(14,2) NOT NULL,
  reason_code VARCHAR(40),
  status VARCHAR(20) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_refunds_txn (original_transaction_id),
  INDEX idx_refunds_updated (updated_at)
);

CREATE TABLE IF NOT EXISTS cancellations (
  cancellation_id BIGINT PRIMARY KEY,
  original_transaction_id BIGINT NOT NULL,
  cancellation_ts DATETIME(6) NOT NULL,
  reason_code VARCHAR(40),
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_cancel_txn (original_transaction_id),
  INDEX idx_cancel_updated (updated_at)
);
