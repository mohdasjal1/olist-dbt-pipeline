# Olist E-Commerce dbt Pipeline Explained

Imagine you are the Chief Data Officer for Olist, the largest department store marketplace in Brazil. Your marketing team says: *"We have over 100,000 orders coming in from different sellers, customers, and payment methods. We need a dashboard to see which product categories are most profitable, and which sellers have the worst delivery times."*

This project is how we build the modern data pipeline to make that happen.

---

## 1. The "What" and the "Why"

**The What:** We built an automated pipeline that takes messy, raw E-Commerce data (spread across 9 different CSV files), loads it into a cloud database, cleans it, joins it all together, and creates perfectly structured "business-ready" tables for analysts to query. We also added a robotic testing system to make sure the data is never wrong.

**The Why:** If you don't build this pipeline, your analysts would have to manually open 9 different massive Excel spreadsheets, try to VLOOKUP them together, and hope they don't crash their computer. We used **Data Engineering (specifically dbt and Snowflake)** to automate this entire process in the cloud.

---

## 2. The Architecture (The "Medallion" Pattern)

In data engineering, we organize our data into three layers, like medals in the Olympics: **Bronze, Silver, and Gold.** We use a tool called **dbt (Data Build Tool)** running on top of **Snowflake** (a super-powerful cloud database) to transform the data between these layers.

### 🥉 Step 1: The Bronze Layer (The "Raw" Layer)
* **What happens:** We run a Python script that takes the 9 raw CSV files from Kaggle and dumps them directly into a Snowflake schema called `RAW`. 
* **Why we do it:** We want a perfect historical record of the raw data exactly as it arrived. If we mess up our cleaning later, we can always go back to the Bronze layer without losing the original data.

### 🥈 Step 2: The Silver Layer (The "Janitor" Layer)
* **What happens:** We use **dbt Staging Models**. We write SQL `SELECT` statements that take the messy data from Bronze and clean it up. We rename weird columns (like changing `order_id_x` to just `order_id`), fix timestamp formats, and handle missing values. We also created **Intermediate Models** to join tables together (like joining Orders with Customers).
* **Why we do it:** Dashboards hate messy data. The Silver layer acts as the "source of truth" for clean, standardized data.

### 🥇 Step 3: The Gold Layer (The "Business" Layer)
* **What happens:** We use **dbt Mart Models**. We build what is called a "Kimball Dimensional Model" containing **Fact Tables** (metrics like revenue and delivery times) and **Dimension Tables** (descriptions like customer names and product categories).
* **Why we do it:** The CEO doesn't want to write complex SQL joins to answer a simple question. The Gold layer creates perfectly summarized, query-ready tables that Power BI or Tableau can read instantly.

---

## 3. The Quality Assurance (The "Inspector")

If bad data makes it to the CEO's dashboard, you get fired. So we added an inspector.

* **What happens:** We added **85 automated dbt tests**. Every time the pipeline runs, dbt checks: *"Are there any duplicate orders? Are there any missing primary keys? Does this customer ID actually exist in the customer table?"*
* **Why we do it:** Data engineers don't just move data; they guarantee its accuracy. If any of these 85 tests fail, the pipeline stops and alerts us before the bad data reaches the dashboard.

## 4. The CI/CD Pipeline (The "Bouncer")

In a real company, 10 data engineers might be writing code at the same time. What if someone writes bad SQL?

* **What happens:** We used **GitHub Actions** and **sqlfluff**. Whenever a data engineer tries to add new code (a Pull Request), a robot in the cloud wakes up. It reads their SQL to make sure it is perfectly formatted (sqlfluff), and then it runs the entire dbt project on a temporary cloud server to make sure it actually works.
* **Why we do it:** This acts like a bouncer at a club. If your code is messy or breaks a test, the bouncer (GitHub Actions) blocks you from merging your code into the main project.

---

### Conclusion
By combining **Snowflake** (Compute & Storage), **dbt** (Transformations & Testing), and **GitHub Actions** (CI/CD Automation), you built an enterprise-grade Analytics Engineering system. This exact "Modern Data Stack" is used by thousands of top tech companies today to handle their data!
