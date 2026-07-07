-- Model: dim_customers.sql
-- Layer: Mart (Dimension Table)
-- Description: Customer dimension. One row per customer_unique_id (true person-level).
--              Includes geo coordinates and order history aggregates.
--              WHY customer_unique_id as grain (not customer_id)?
--              Olist creates a new customer_id per order for privacy.
--              Using customer_id would create duplicate customers in the dimension.
--              customer_unique_id is the true dedup key.
-- Dependencies: int_customers_enriched, stg_orders
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='table',
    schema='marts'
) }}

WITH customers_enriched AS (
    SELECT * FROM {{ ref('int_customers_enriched') }}
),

-- Aggregate order history per unique customer
order_history AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)              AS total_orders,
        MIN(o.order_purchase_at)                AS first_order_at,
        MAX(o.order_purchase_at)                AS last_order_at,
        DATEDIFF('day', MIN(o.order_purchase_at), MAX(o.order_purchase_at)) AS customer_tenure_days

    FROM customers_enriched AS c
    LEFT JOIN {{ ref('stg_orders') }} AS o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id
),

-- One row per customer_unique_id (pick any customer_id — they're different per order)
deduped AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY customer_id) AS rn

    FROM customers_enriched
)

SELECT
    d.customer_unique_id,
    d.customer_id,                 -- Most recent/first customer_id for FK reference
    d.customer_zip_code_prefix,
    d.customer_city,
    d.customer_state,
    d.customer_latitude,
    d.customer_longitude,

    -- Order behavior
    oh.total_orders,
    oh.first_order_at,
    oh.last_order_at,
    oh.customer_tenure_days,

    -- Customer type (repeat vs one-time)
    CASE
        WHEN oh.total_orders > 1 THEN 'Repeat'
        ELSE 'One-time'
    END AS customer_type

FROM deduped AS d
LEFT JOIN order_history AS oh
    ON d.customer_unique_id = oh.customer_unique_id

WHERE d.rn = 1
