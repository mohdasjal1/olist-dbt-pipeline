# Olist E-Commerce dbt Pipeline for Reporting

> **End-to-end data engineering pipeline:** Python ingestion → Snowflake → dbt Core → GitHub Actions CI/CD

[![dbt CI Pipeline](https://github.com/mohdasjal1/olist-dbt-pipeline/actions/workflows/dbt_ci.yml/badge.svg)](https://github.com/mohdasjal1/olist-dbt-pipeline/actions/workflows/dbt_ci.yml)
[![dbt](https://img.shields.io/badge/dbt-1.9.0-orange)](https://www.getdbt.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Cloud%20Warehouse-29B5E8)](https://www.snowflake.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Project Overview

This project transforms the **Olist Brazilian E-Commerce dataset** (100,000+ orders, 9 source tables)
into a production-ready analytics warehouse using modern data engineering tools.

**Stack:** Python · Snowflake · dbt Core · sqlfluff · GitHub Actions

---

## Architecture

```
[Kaggle CSVs: 9 tables, 100K+ orders]
            |
            | load_to_snowflake.py (bulk COPY INTO)
            v
[Snowflake RAW Schema]
            |
            | dbt staging models (9 views)
            v
[Snowflake STAGING Schema]
            |
            | dbt intermediate models (3 views)
            v
[Snowflake INTERMEDIATE Schema]
            |
            | dbt mart models (5 tables)
            v
[Snowflake MARTS Schema: 2 Facts + 3 Dimensions]
            |
            | BI Tools / SQL Analytics
            v
[Business Intelligence]
```

**Full architecture details:** [docs/architecture.md](docs/architecture.md)
**Deep Dive Technical Explanation (For Students/Interviewers):** [docs/project_explanation.md](docs/project_explanation.md)
---

## Dataset

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle

| Table | Description | Rows |
|-------|-------------|------|
| olist_orders_dataset | Orders with status and timestamps | 99,441 |
| olist_order_items_dataset | Line items per order | 112,650 |
| olist_customers_dataset | Customer data | 99,441 |
| olist_products_dataset | Product catalogue | 32,951 |
| olist_sellers_dataset | Seller/merchant data | 3,095 |
| olist_order_payments_dataset | Payment methods and values | 103,886 |
| olist_order_reviews_dataset | Customer reviews (1-5 stars) | 99,224 |
| olist_geolocation_dataset | Zip code to lat/lng mapping | 1,000,163 |
| product_category_name_translation | Portuguese → English categories | 71 |

---

## Business Questions Answered

1. **Which product categories generate the most revenue?** → `fct_order_items` + `dim_products`
2. **What is the average delivery time by state?** → `fct_orders` + `dim_customers`
3. **Which sellers have the highest order cancellation rates?** → `dim_sellers`
4. **What payment methods do customers prefer by region?** → `fct_orders`
5. **How does review score correlate with delivery time?** → `fct_orders`

---

## Project Structure

```
olist-dbt-pipeline/
├── .github/
│   └── workflows/
│       └── dbt_ci.yml          ← CI/CD: PR validation pipeline
├── dbt_project/
│   ├── models/
│   │   ├── staging/            ← 9 staging models (views)
│   │   ├── intermediate/       ← 3 intermediate models (views)
│   │   └── marts/              ← 5 mart models (tables)
│   ├── dbt_project.yml         ← dbt project config
│   └── packages.yml            ← dbt package dependencies
├── ingestion/
│   └── load_to_snowflake.py    ← Python: CSV → Snowflake RAW
├── data/raw/                   ← Place Kaggle CSV files here (gitignored)
├── docs/
│   └── architecture.md         ← Full architecture documentation
├── .sqlfluff                   ← SQL linting config
├── requirements.txt            ← Python dependencies
└── README.md
```

---

## Setup Instructions

### Prerequisites
- Python 3.11+
- Snowflake Free Trial account ($400 credits)
- dbt Core installed

### 1. Clone and Setup Environment

```bash
git clone https://github.com/mohdasjal1/olist-dbt-pipeline.git
cd olist-dbt-pipeline
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### 2. Create Snowflake Resources

Run this in your Snowflake UI (Worksheets):

```sql
CREATE DATABASE IF NOT EXISTS OLIST_DB;
CREATE WAREHOUSE IF NOT EXISTS OLIST_WH WITH WAREHOUSE_SIZE = 'X-SMALL' AUTO_SUSPEND = 60;
CREATE SCHEMA IF NOT EXISTS OLIST_DB.RAW;
CREATE SCHEMA IF NOT EXISTS OLIST_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS OLIST_DB.INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS OLIST_DB.MARTS;
```

### 3. Configure Credentials

```bash
# Set environment variables (never put credentials in code)
# Windows:
set SNOWFLAKE_ACCOUNT=your-org-accountname
set SNOWFLAKE_USER=your-username
set SNOWFLAKE_PASSWORD=your-password
```

Copy `dbt_project/profiles.yml` template and fill in your account details.

### 4. Load Data to Snowflake

```bash
# Place all 9 Kaggle CSVs in data/raw/ first
python ingestion/load_to_snowflake.py
```

### 5. Run dbt Pipeline

```bash
cd dbt_project
dbt deps            # Install packages
dbt debug           # Verify connection
dbt build           # Run all models + tests
dbt docs generate   # Build documentation
dbt docs serve      # View docs in browser at localhost:8080
```

---

## dbt Models

### Staging Layer (9 views)
| Model | Source | Key Transformations |
|-------|--------|---------------------|
| stg_orders | RAW.OLIST_ORDERS_DATASET | Cast timestamps, rename cols |
| stg_order_items | RAW.OLIST_ORDER_ITEMS_DATASET | Cast price/freight to FLOAT |
| stg_customers | RAW.OLIST_CUSTOMERS_DATASET | Standardize state codes |
| stg_products | RAW.OLIST_PRODUCTS_DATASET | Cast dimensions, handle NULL categories |
| stg_sellers | RAW.OLIST_SELLERS_DATASET | Standardize state/city |
| stg_payments | RAW.OLIST_ORDER_PAYMENTS_DATASET | Cast payment_value |
| stg_reviews | RAW.OLIST_ORDER_REVIEWS_DATASET | Cast score, handle NULL comments |
| stg_geolocation | RAW.OLIST_GEOLOCATION_DATASET | Cast lat/lng, deduplicate by zip |
| stg_product_category | RAW.PRODUCT_CATEGORY_NAME_TRANSLATION | Rename columns |

### Intermediate Layer (3 views)
| Model | Dependencies | Purpose |
|-------|-------------|---------|
| int_orders_enriched | stg_orders + stg_customers + stg_payments | Delivery metrics, payment summary |
| int_sellers_performance | stg_order_items + stg_sellers + stg_orders + stg_reviews | Seller KPIs |
| int_customers_enriched | stg_customers + stg_geolocation | Customer + geo coordinates |

### Mart Layer (5 tables)
| Model | Type | Grain | Business Use |
|-------|------|-------|-------------|
| fct_orders | Fact | Per order | Delivery analysis, payment preferences |
| fct_order_items | Fact | Per item | Revenue by category, product analytics |
| dim_customers | Dimension | Per unique customer | Customer segmentation |
| dim_products | Dimension | Per product | Product catalogue with sales metrics |
| dim_sellers | Dimension | Per seller | Seller performance and cancellation rates |

---

## CI/CD Pipeline

Every Pull Request to `main` triggers:

```
1. sqlfluff lint     ← SQL code quality check
2. dbt deps          ← Install packages
3. dbt build         ← Run all models
4. dbt test          ← Data quality checks
5. dbt docs generate ← Build documentation
```

PR is **blocked** if any step fails.

---

## Data Quality Tests

Every model has dbt tests enforcing:
- `not_null` — primary keys are never NULL
- `unique` — no duplicate records
- `relationships` — referential integrity (foreign key validation)
- `accepted_values` — enum fields only contain valid values

---

## Author

**Mohammad Asjad** — Data Engineering Student, Karachi, Pakistan

- GitHub: [mohdasjad1](https://github.com/mohdasjad1)
- Project 1: [azure-databricks-de-pipeline](https://github.com/mohdasjad1/azure-databricks-project)

---

## License

MIT License — Free to use for portfolio and learning purposes.

