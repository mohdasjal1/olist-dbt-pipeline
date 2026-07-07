"""
scripts/snowflake_setup.py
One-time setup: creates OLIST_DB, OLIST_WH, and all 4 schemas in Snowflake.
Credentials read from environment variables — never hardcoded.
"""
import os
import sys

try:
    import snowflake.connector
except ImportError:
    print("ERROR: snowflake-connector-python not installed. Run: pip install snowflake-connector-python")
    sys.exit(1)

ACCOUNT  = os.environ["SNOWFLAKE_ACCOUNT"]
USER     = os.environ["SNOWFLAKE_USER"]
PASSWORD = os.environ["SNOWFLAKE_PASSWORD"]

print(f"Connecting to Snowflake account: {ACCOUNT}")

conn = snowflake.connector.connect(
    account=ACCOUNT,
    user=USER,
    password=PASSWORD,
    login_timeout=30,
)

cursor = conn.cursor()

setup_statements = [
    ("Creating warehouse OLIST_WH",
     "CREATE WAREHOUSE IF NOT EXISTS OLIST_WH WITH WAREHOUSE_SIZE = 'X-SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE"),
    ("Creating database OLIST_DB",
     "CREATE DATABASE IF NOT EXISTS OLIST_DB"),
    ("Creating schema RAW",
     "CREATE SCHEMA IF NOT EXISTS OLIST_DB.RAW"),
    ("Creating schema STAGING",
     "CREATE SCHEMA IF NOT EXISTS OLIST_DB.STAGING"),
    ("Creating schema INTERMEDIATE",
     "CREATE SCHEMA IF NOT EXISTS OLIST_DB.INTERMEDIATE"),
    ("Creating schema MARTS",
     "CREATE SCHEMA IF NOT EXISTS OLIST_DB.MARTS"),
    ("Using warehouse",
     "USE WAREHOUSE OLIST_WH"),
    ("Using database",
     "USE DATABASE OLIST_DB"),
]

for description, sql in setup_statements:
    print(f"  >> {description}...", end=" ", flush=True)
    cursor.execute(sql)
    print("DONE")

cursor.close()
conn.close()

print("\n========================================")
print("Snowflake setup COMPLETE!")
print("  Database : OLIST_DB")
print("  Warehouse: OLIST_WH (X-Small, auto-suspend 60s)")
print("  Schemas  : RAW | STAGING | INTERMEDIATE | MARTS")
print("========================================")
