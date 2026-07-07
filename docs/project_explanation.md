# Project 2 Deep Dive: Snowflake, dbt & CI/CD Pipeline

Welcome to the technical explanation of your second data engineering project! This document breaks down exactly what we built, why we chose these tools, and how everything works together. This is crucial for your understanding so you can confidently explain this project in technical interviews.

---

## 1. The Goal
We took a raw Kaggle dataset (Olist Brazilian E-Commerce, ~100k orders) and built a professional, automated pipeline to turn it into clean, reliable, and query-ready tables that a Business Intelligence (BI) team can plug into Tableau or PowerBI.

---

## 2. The Tech Stack

### Why Snowflake?
Snowflake is a modern, cloud-native Data Warehouse. 
- **Separation of Storage and Compute:** You can store massive amounts of data cheaply and only pay for compute (the "Warehouse") when you run queries.
- **Ease of Use:** You don't have to manage servers. We created `OLIST_DB` and an `X-SMALL` warehouse with just a few SQL commands via a Python script.

### Why dbt (Data Build Tool)?
In the old days, data engineers wrote thousands of lines of messy SQL scripts or used drag-and-drop ETL tools. **dbt changed everything.**
- It allows you to write simple `SELECT` statements (Models) while dbt handles the underlying `CREATE TABLE` or `CREATE VIEW` commands automatically.
- It treats SQL like software code (with version control, testing, and CI/CD).
- It handles the dependency graph automatically (dbt knows `fct_orders` relies on `stg_orders`, so it builds them in the right order).

### Why GitHub Actions (CI/CD)?
CI/CD stands for Continuous Integration / Continuous Deployment. In a team of 10 data engineers, if someone writes bad SQL, it can break the entire dashboard for the CEO. 
- GitHub Actions is a robot that runs tests in the cloud.
- Whenever you open a Pull Request, the robot checks out your code, connects to Snowflake, and tests your SQL to make sure you didn't break anything. If the tests fail, it blocks you from merging!

---

## 3. The Medallion Architecture (dbt Layers)

We used a 3-layer architecture, which is the industry standard for organizing data models.

### Layer 1: Staging (Bronze/Silver)
- **Goal:** Clean up the messy raw data.
- **What we did:** We read directly from `RAW.OLIST_ORDERS_DATASET`, casted strings to Dates and Floats, renamed columns to be lowercase, and handled NULL values. 
- **Materialization:** Views. We don't need to store this data twice, we just want a clean lens over the raw data.

### Layer 2: Intermediate
- **Goal:** Join tables together and do heavy lifting before the final step.
- **What we did:** We joined `stg_orders` with `stg_customers` and `stg_payments` to create `int_orders_enriched`. This keeps our final layer clean and modular.

### Layer 3: Marts (Gold)
- **Goal:** Business-ready tables built using **Kimball Dimensional Modeling**.
- **Fact Tables (`fct_orders`, `fct_order_items`):** Massive tables that record events (like an order happening). They contain numerical metrics (price, freight value, delivery time).
- **Dimension Tables (`dim_customers`, `dim_products`, `dim_sellers`):** Descriptive tables that tell you *who*, *what*, and *where* the facts relate to. 
- **Materialization:** Tables. BI tools query these constantly, so we want the data pre-computed and stored physically for maximum speed.

---

## 4. Automated Testing & Code Quality

### Data Quality Tests (dbt tests)
Data engineers don't just move data; they guarantee its accuracy. We attached **85 automated tests** to our models using `schema.yml` files.
- `not_null`: Ensures primary keys (like `order_id`) are never empty.
- `unique`: Ensures we don't accidentally duplicate orders during a bad SQL JOIN.
- `relationships`: Ensures that every `customer_id` in the Orders table actually exists in the Customers table.

### Code Linting (sqlfluff)
`sqlfluff` is a strict SQL linter. If you write `select * from Tbl`, sqlfluff will yell at you to write `SELECT * FROM tbl`. It forces your entire team to write SQL in the exact same style, making the codebase clean and professional.

---

## 5. Summary of the Workflow

1. You pushed raw CSVs into **Snowflake** using Python.
2. You wrote **dbt models** locally and ran `dbt run` and `dbt test` to transform the data.
3. You pushed your code to a new branch on **GitHub** and opened a Pull Request.
4. **GitHub Actions** ran a 30-minute automated test suite, linting your SQL and running dbt in the cloud.
5. You fixed a tricky BOM (Byte Order Mark) bug and yaml indentation bug.
6. The CI/CD pipeline passed, and you **Merged** your code into Production (`main`).

You now have a fully functioning Analytics Engineering pipeline on your resume!
