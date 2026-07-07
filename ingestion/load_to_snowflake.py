"""
ingestion/load_to_snowflake.py
================================
Project: Olist E-Commerce dbt Pipeline
Layer: Ingestion (Python -> Snowflake RAW schema)
Author: Mohammad Asjad
Last Updated: 2026-07-07

Description:
    Reads all 9 Olist CSV files from data/raw/ and loads each into
    the RAW schema in Snowflake. Uses write_pandas for efficient bulk loading.

    WHY write_pandas over INSERT statements?
    - write_pandas uses COPY INTO under the hood (Snowflake bulk load)
    - 10-100x faster than row-by-row INSERT for 100K+ rows
    - Handles data type inference automatically

Usage:
    # Set environment variables first:
    # Windows: set SNOWFLAKE_PASSWORD=yourpassword
    # Linux/Mac: export SNOWFLAKE_PASSWORD=yourpassword

    python ingestion/load_to_snowflake.py

Requirements:
    pip install -r requirements.txt
"""

import os
import sys
import time
from pathlib import Path

import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas
from loguru import logger


# ============================================================
# CONFIGURATION
# ============================================================

# Project root = parent of this script's directory
PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / "data" / "raw"

# Snowflake connection config
# WHY environment variables? Credentials never go in code.
# GitHub Actions uses GitHub Secrets -> env vars. Same pattern locally.
SNOWFLAKE_CONFIG = {
    "account": os.environ.get("SNOWFLAKE_ACCOUNT"),
    "user": os.environ.get("SNOWFLAKE_USER"),
    "password": os.environ.get("SNOWFLAKE_PASSWORD"),
    "database": os.environ.get("SNOWFLAKE_DATABASE", "OLIST_DB"),
    "warehouse": os.environ.get("SNOWFLAKE_WAREHOUSE", "OLIST_WH"),
    "role": os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
    "schema": "RAW",
}

# Mapping: CSV filename -> Snowflake RAW table name
# Convention: ALL CAPS for Snowflake table names (Snowflake is case-insensitive
# but uppercase avoids quoting headaches in SQL)
CSV_TO_TABLE_MAP = {
    "olist_orders_dataset.csv": "OLIST_ORDERS_DATASET",
    "olist_order_items_dataset.csv": "OLIST_ORDER_ITEMS_DATASET",
    "olist_customers_dataset.csv": "OLIST_CUSTOMERS_DATASET",
    "olist_products_dataset.csv": "OLIST_PRODUCTS_DATASET",
    "olist_sellers_dataset.csv": "OLIST_SELLERS_DATASET",
    "olist_order_payments_dataset.csv": "OLIST_ORDER_PAYMENTS_DATASET",
    "olist_order_reviews_dataset.csv": "OLIST_ORDER_REVIEWS_DATASET",
    "olist_geolocation_dataset.csv": "OLIST_GEOLOCATION_DATASET",
    "product_category_name_translation.csv": "PRODUCT_CATEGORY_NAME_TRANSLATION",
}


# ============================================================
# SETUP LOGGING
# ============================================================

def setup_logging() -> None:
    """Configure loguru for structured console + file logging."""
    log_dir = PROJECT_ROOT / "logs"
    log_dir.mkdir(exist_ok=True)

    logger.remove()  # Remove default handler

    # Console: readable format
    logger.add(
        sys.stdout,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | {message}",
        level="INFO",
        colorize=True,
    )

    # File: machine-parseable for CI/CD logs
    logger.add(
        log_dir / "ingestion_{time:YYYY-MM-DD}.log",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {message}",
        level="DEBUG",
        rotation="10 MB",
        retention="7 days",
    )


# ============================================================
# VALIDATION
# ============================================================

def validate_config() -> None:
    """Validate all required environment variables are set before attempting connection."""
    required = ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD"]
    missing = [var for var in required if not os.environ.get(var)]

    if missing:
        logger.error(f"Missing required environment variables: {missing}")
        logger.error("Set them before running:")
        logger.error("  Windows: set SNOWFLAKE_ACCOUNT=your-account-identifier")
        logger.error("  Linux/Mac: export SNOWFLAKE_ACCOUNT=your-account-identifier")
        sys.exit(1)

    logger.info("All required environment variables are set.")


def validate_csv_files() -> list[Path]:
    """Check all CSV files exist in data/raw/ before attempting upload."""
    missing_files = []
    found_files = []

    for csv_name in CSV_TO_TABLE_MAP.keys():
        csv_path = DATA_DIR / csv_name
        if not csv_path.exists():
            missing_files.append(csv_name)
        else:
            found_files.append(csv_path)

    if missing_files:
        logger.warning(f"Missing CSV files in {DATA_DIR}:")
        for f in missing_files:
            logger.warning(f"  - {f}")
        logger.warning("These files will be skipped. Copy them from your Downloads/archive folder.")

    logger.info(f"Found {len(found_files)}/{len(CSV_TO_TABLE_MAP)} CSV files ready to load.")
    return found_files


# ============================================================
# SNOWFLAKE SETUP
# ============================================================

def create_snowflake_connection() -> snowflake.connector.SnowflakeConnection:
    """Create and return authenticated Snowflake connection."""
    logger.info(f"Connecting to Snowflake account: {SNOWFLAKE_CONFIG['account']}")

    try:
        conn = snowflake.connector.connect(
            account=SNOWFLAKE_CONFIG["account"],
            user=SNOWFLAKE_CONFIG["user"],
            password=SNOWFLAKE_CONFIG["password"],
            database=SNOWFLAKE_CONFIG["database"],
            warehouse=SNOWFLAKE_CONFIG["warehouse"],
            role=SNOWFLAKE_CONFIG["role"],
            schema=SNOWFLAKE_CONFIG["schema"],
        )
        logger.success(f"Connected to Snowflake: {SNOWFLAKE_CONFIG['database']}.{SNOWFLAKE_CONFIG['schema']}")
        return conn

    except snowflake.connector.errors.DatabaseError as e:
        logger.error(f"Snowflake connection failed: {e}")
        logger.error("Check your account identifier format. It should be: orgname-accountname")
        logger.error("Find it in Snowflake UI: bottom-left account menu -> Copy Account Identifier")
        sys.exit(1)


def ensure_snowflake_objects(conn: snowflake.connector.SnowflakeConnection) -> None:
    """
    Activate the correct database, warehouse, and schema context for this session.
    WHY: Objects were already created by scripts/snowflake_setup.py.
    We only need USE statements here — no CREATE needed.
    """
    cursor = conn.cursor()

    setup_sql = [
        f"USE ROLE {SNOWFLAKE_CONFIG['role']}",
        f"USE WAREHOUSE {SNOWFLAKE_CONFIG['warehouse']}",
        f"USE DATABASE {SNOWFLAKE_CONFIG['database']}",
        "USE SCHEMA RAW",
    ]

    for sql in setup_sql:
        cursor.execute(sql)

    cursor.close()
    logger.info("Snowflake context set: database, warehouse, schema active.")


# ============================================================
# DATA LOADING
# ============================================================

def read_csv(csv_path: Path) -> pd.DataFrame:
    """
    Read CSV with appropriate dtypes. Returns DataFrame.
    WHY low_memory=False: Olist CSVs have mixed types in some columns.
    Without this, pandas guesses dtypes per chunk and can be inconsistent.
    """
    logger.debug(f"Reading: {csv_path.name}")

    df = pd.read_csv(csv_path, low_memory=False)

    # Standardize column names to UPPER_CASE for Snowflake
    # WHY: Snowflake stores unquoted identifiers as uppercase.
    # write_pandas quotes column names — matching case avoids query headaches.
    df.columns = [col.upper() for col in df.columns]

    logger.debug(f"  Rows: {len(df):,} | Columns: {list(df.columns)}")
    return df


def load_dataframe_to_snowflake(
    conn: snowflake.connector.SnowflakeConnection,
    df: pd.DataFrame,
    table_name: str,
) -> dict:
    """
    Load a pandas DataFrame into a Snowflake table using write_pandas (bulk COPY INTO).

    Returns a result dict with status and row counts.

    WHY overwrite (if_exists style) on first load:
    - This is a full refresh ingestion pattern.
    - For incremental loads in production, you'd use MERGE or INSERT.
    - Full refresh is appropriate here because CSVs are static snapshots.
    """
    start_time = time.time()

    try:
        success, nchunks, nrows, _ = write_pandas(
            conn=conn,
            df=df,
            table_name=table_name,
            database=SNOWFLAKE_CONFIG["database"],
            schema="RAW",
            overwrite=True,          # Truncate + reload (full refresh)
            auto_create_table=True,  # Create table if not exists, infer schema
            quote_identifiers=False, # Uppercase cols, no quoting needed
        )

        elapsed = time.time() - start_time

        return {
            "table": table_name,
            "status": "SUCCESS" if success else "FAILED",
            "rows_loaded": nrows,
            "chunks": nchunks,
            "elapsed_seconds": round(elapsed, 2),
        }

    except Exception as e:
        elapsed = time.time() - start_time
        logger.error(f"  Failed to load {table_name}: {e}")
        return {
            "table": table_name,
            "status": "FAILED",
            "rows_loaded": 0,
            "chunks": 0,
            "elapsed_seconds": round(elapsed, 2),
            "error": str(e),
        }


# ============================================================
# MAIN ORCHESTRATOR
# ============================================================

def run_ingestion() -> None:
    """
    Main ingestion pipeline.
    Orchestrates: validate -> connect -> setup -> load all CSVs -> report.
    """
    logger.info("=" * 60)
    logger.info("OLIST E-COMMERCE DATA INGESTION PIPELINE")
    logger.info("Target: Snowflake RAW schema")
    logger.info("=" * 60)

    # Step 1: Validate config and files
    validate_config()
    available_files = validate_csv_files()

    if not available_files:
        logger.error("No CSV files found. Aborting.")
        sys.exit(1)

    # Step 2: Connect to Snowflake
    conn = create_snowflake_connection()

    # Step 3: Ensure Snowflake objects exist
    ensure_snowflake_objects(conn)

    # Step 4: Load each CSV
    results = []
    total_rows = 0

    for csv_path in available_files:
        table_name = CSV_TO_TABLE_MAP[csv_path.name]
        logger.info(f"Loading: {csv_path.name} -> RAW.{table_name}")

        df = read_csv(csv_path)
        result = load_dataframe_to_snowflake(conn, df, table_name)
        results.append(result)

        if result["status"] == "SUCCESS":
            total_rows += result["rows_loaded"]
            logger.success(
                f"  [OK] {table_name}: {result['rows_loaded']:,} rows in {result['elapsed_seconds']}s"
            )
        else:
            logger.error(f"  [FAIL] {table_name}: FAILED - {result.get('error', 'Unknown error')}")

    # Step 5: Close connection
    conn.close()

    # Step 6: Summary report
    logger.info("=" * 60)
    logger.info("INGESTION SUMMARY")
    logger.info("=" * 60)

    successful = [r for r in results if r["status"] == "SUCCESS"]
    failed = [r for r in results if r["status"] == "FAILED"]

    for r in results:
        status_icon = "[OK]  " if r["status"] == "SUCCESS" else "[FAIL]"
        logger.info(f"  {status_icon} {r['table']:<45} {r['rows_loaded']:>8,} rows  {r['elapsed_seconds']}s")

    logger.info("-" * 60)
    logger.info(f"  Tables loaded: {len(successful)}/{len(results)}")
    logger.info(f"  Total rows:    {total_rows:,}")
    logger.info(f"  Failures:      {len(failed)}")

    if failed:
        logger.error("FAILED TABLES:")
        for r in failed:
            logger.error(f"  - {r['table']}: {r.get('error', 'Unknown')}")
        sys.exit(1)
    else:
        logger.success("All tables loaded successfully into Snowflake RAW schema!")
        logger.success("Next step: Run dbt build to transform data through Staging -> Intermediate -> Marts")


if __name__ == "__main__":
    setup_logging()
    run_ingestion()
