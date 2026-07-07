-- Model: int_sellers_performance.sql
-- Layer: Intermediate
-- Description: Calculates seller-level KPIs by aggregating order items, orders,
--              and reviews. Powers dim_sellers in the mart layer.
--              WHY intermediate layer? These aggregations are reusable across
--              multiple mart models. DRY principle — compute once, reference many times.
-- Dependencies: stg_order_items, stg_sellers, stg_orders, stg_reviews
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

orders AS (
    SELECT order_id, order_status FROM {{ ref('stg_orders') }}
),

sellers AS (
    SELECT * FROM {{ ref('stg_sellers') }}
),

reviews AS (
    SELECT * FROM {{ ref('stg_reviews') }}
),

-- Join items to order status for cancellation analysis
items_with_status AS (
    SELECT
        oi.seller_id,
        oi.order_id,
        oi.product_id,
        oi.item_price,
        oi.freight_value,
        oi.total_item_value,
        o.order_status

    FROM order_items AS oi
    LEFT JOIN orders AS o
        ON oi.order_id = o.order_id
),

-- Join reviews to sellers via order items (seller -> order -> review)
seller_reviews AS (
    SELECT
        oi.seller_id,
        AVG(r.review_score) AS avg_review_score,
        COUNT(r.review_id)  AS total_reviews

    FROM order_items AS oi
    LEFT JOIN reviews AS r
        ON oi.order_id = r.order_id

    GROUP BY oi.seller_id
),

-- Aggregate seller performance metrics
seller_metrics AS (
    SELECT
        seller_id,
        COUNT(DISTINCT order_id)                           AS total_orders,
        COUNT(DISTINCT product_id)                         AS unique_products_sold,
        COUNT(*)                                           AS total_items_sold,
        SUM(item_price)                                    AS total_revenue,
        SUM(freight_value)                                 AS total_freight_charged,
        AVG(item_price)                                    AS avg_item_price,

        -- Cancellation rate: key interview metric
        ROUND(
            COUNT(CASE WHEN order_status = 'canceled' THEN 1 END) * 100.0
            / NULLIF(COUNT(DISTINCT order_id), 0),
            2
        )                                                  AS cancellation_rate_pct

    FROM items_with_status
    GROUP BY seller_id
)

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.seller_zip_code_prefix,

    -- Performance KPIs
    sm.total_orders,
    sm.total_items_sold,
    sm.unique_products_sold,
    sm.total_revenue,
    sm.total_freight_charged,
    sm.avg_item_price,
    sm.cancellation_rate_pct,

    -- Review metrics
    sr.avg_review_score,
    sr.total_reviews,

    -- Seller tier classification based on revenue
    CASE
        WHEN sm.total_revenue >= 50000  THEN 'Platinum'
        WHEN sm.total_revenue >= 10000  THEN 'Gold'
        WHEN sm.total_revenue >= 1000   THEN 'Silver'
        ELSE 'Bronze'
    END AS seller_tier

FROM sellers AS s
LEFT JOIN seller_metrics AS sm
    ON s.seller_id = sm.seller_id
LEFT JOIN seller_reviews AS sr
    ON s.seller_id = sr.seller_id
