# Architecture Documentation
# Project: Olist E-Commerce dbt Pipeline
# Author: Mohammad Asjad
# Last Updated: 2026-07-07

## Architecture Overview

This project implements a modern ELT (Extract, Load, Transform) data pipeline for the
Olist Brazilian E-Commerce dataset. It uses Python for data loading and dbt Core for
SQL-based transformation inside Snowflake.

```
Data Flow:

[Kaggle CSVs]
      |
      | Python ingestion script (load_to_snowflake.py)
      | write_pandas -> COPY INTO (bulk load)
      v
[Snowflake RAW Schema]  <-- 9 tables, raw data as-is
      |
      | dbt staging models (views)
      | - Cast types, rename columns, handle NULLs
      v
[Snowflake STAGING Schema]  <-- 9 staging views
      |
      | dbt intermediate models (views)
      | - Join related tables
      | - Calculate derived metrics
      v
[Snowflake INTERMEDIATE Schema]  <-- 3 intermediate views
      |
      | dbt mart models (tables)
      | - Business-ready fact and dimension tables
      v
[Snowflake MARTS Schema]  <-- 2 fact tables + 3 dimension tables
      |
      | Analytics / BI tools
      v
[Business Intelligence / Reporting]
```

## Why ELT (not ETL)?

Traditional ETL transforms data BEFORE loading.
Modern ELT loads raw data FIRST, then transforms inside the warehouse.

WHY ELT is better for this project:
- Snowflake compute is cheap and elastic — transformation inside warehouse is fast
- Raw data is preserved forever (reprocess any time with new business logic)
- dbt runs SQL inside Snowflake — no external compute needed
- Cloud warehouses (Snowflake, BigQuery, Redshift) are optimized for SQL at scale

## Technology Choices

### Snowflake (Data Warehouse)
WHY Snowflake over BigQuery/Redshift?
- Separation of compute and storage: pause warehouse, stop paying
- X-Small warehouse sufficient for 100K rows (cheapest tier)
- Time Travel: query data as it was at any point in the past (disaster recovery)
- Automatic scaling: if dataset grew 100x, just resize the warehouse

### dbt Core (Transformation)
WHY dbt over writing raw SQL scripts?
- Version control: every transformation is a .sql file in Git
- Lineage: dbt knows which model depends on which — never run in wrong order
- Testing: built-in data quality tests (not_null, unique, relationships)
- Documentation: auto-generated web docs from YAML descriptions
- Modularity: ref() macro manages dependencies automatically

### GitHub Actions (CI/CD)
WHY CI/CD for a data project?
- Every PR to main triggers automated validation
- sqlfluff catches SQL style issues (consistent code = easier maintenance)
- dbt build validates every model compiles AND runs without error
- dbt test validates data quality assertions pass
- Bad code cannot merge to main — data quality is enforced by the pipeline

## 3-Layer Architecture

### Layer 1: Staging (stg_)
- Materialized as: VIEWS (no storage cost, always fresh)
- Responsibility: Clean and standardize raw data ONLY
- Rule: No joins, no aggregations, no business logic
- 9 models: one per source table

### Layer 2: Intermediate (int_)
- Materialized as: VIEWS
- Responsibility: Join related staging models, compute derived metrics
- Rule: Business logic lives here, not in marts
- 3 models: enriched orders, seller performance, enriched customers

### Layer 3: Marts (fct_ and dim_)
- Materialized as: TABLES (persisted for fast query performance)
- Responsibility: Business-ready tables for analytics
- 2 fact tables + 3 dimension tables

## Snowflake Cost Management

Warehouse: OLIST_WH (X-Small)
- Auto-suspend: 60 seconds of inactivity
- Auto-resume: instant on query
- Cost: ~$0.04/compute-credit
- Full dbt run on this dataset: < 2 minutes = < $0.01

Total estimated cost for development: < $5 from $400 free trial credits

## Business Questions Answered

| Question | Table(s) Used | SQL Pattern |
|----------|---------------|-------------|
| Which product categories generate most revenue? | fct_order_items + dim_products | GROUP BY category_name_en, SUM(item_price) |
| Average delivery time by state? | fct_orders + dim_customers | GROUP BY customer_state, AVG(actual_delivery_days) |
| Sellers with highest cancellation rate? | dim_sellers | ORDER BY cancellation_rate_pct DESC |
| Payment methods by region? | fct_orders | GROUP BY customer_state, primary_payment_type |
| Review score vs delivery time correlation? | fct_orders | review_score vs actual_delivery_days scatter |
