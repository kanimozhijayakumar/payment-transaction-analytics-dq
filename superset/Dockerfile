FROM apache/superset:6.0.0
USER root
# PostgreSQL is the lab warehouse. Keep PyMySQL too so you can optionally
# compare source-vs-warehouse data from Superset during exercises.
RUN pip install --no-cache-dir psycopg2-binary pymysql
USER superset
