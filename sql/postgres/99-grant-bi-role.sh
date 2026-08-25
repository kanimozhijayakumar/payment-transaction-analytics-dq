#!/bin/bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=bi_user="$POSTGRES_BI_USER" --set=db_name="$POSTGRES_DB" <<'SQL'
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'db_name', :'bi_user')\gexec
GRANT USAGE ON SCHEMA dw, control TO :"bi_user";
GRANT SELECT ON ALL TABLES IN SCHEMA dw, control TO :"bi_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA dw GRANT SELECT ON TABLES TO :"bi_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA control GRANT SELECT ON TABLES TO :"bi_user";
SQL
