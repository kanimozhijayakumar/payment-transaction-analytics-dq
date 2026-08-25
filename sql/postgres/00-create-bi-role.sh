#!/bin/bash
set -euo pipefail

# Runs only on first PostgreSQL volume initialization.
# The BI account is intentionally separate from the warehouse owner.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=bi_user="$POSTGRES_BI_USER" --set=bi_password="$POSTGRES_BI_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'bi_user', :'bi_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'bi_user')\gexec
SQL
