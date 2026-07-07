-- Model: fct_orders.sql
-- Layer: Mart (Fact Table)
-- Description: Central fact table. One row per order. Contains all order metrics
--              including delivery times, payment info, and customer location.
--              This is the PRIMARY TABLE for interview demos and dashboard queries.
-- Dependencies: int_orders_enriched, stg_reviews
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07
-- Interview Answer: "This table answers: delivery time by state, on-time rate, 
--                   payment method preferences, review score vs delivery correlation."

{{ config(
    materialized='table',
    schema='marts'
) }}

WITH orders_enriched AS (
    SELECT * FROM {{ ref('int_orders_enriched') }}
),

-- One review per order (take the most recent if duplicates exist)
reviews AS (
    SELECT
        order_id,
        review_score,
        review_comment_message,
        review_created_at,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_created_at DESC) AS rn

    FROM {{ ref('stg_reviews') }}
),

latest_review AS (
    SELECT * FROM reviews WHERE rn = 1
)

SELECT
    -- Surrogate key
    o.order_id,

    -- Foreign keys (for joining to dimension tables)
    o.customer_id,
    o.customer_unique_id,

    -- Order attributes
    o.order_status,
    o.order_purchase_at,
    o.order_approved_at,
    o.order_delivered_to_carrier_at,
    o.order_delivered_to_customer_at,
    o.order_estimated_delivery_at,

    -- Delivery metrics (business KPIs)
    o.actual_delivery_days,
    o.estimated_delivery_days,
    o.is_delivered_on_time,
    o.delivery_delay_days,

    -- Payment
    o.total_payment_value,
    o.primary_payment_type,
    o.payment_type_count,
    o.total_installments,

    -- Customer geography (for "delivery time by state" analysis)
    o.customer_city,
    o.customer_state,
    o.customer_zip_code_prefix,

    -- Review
    r.review_score,
    r.review_comment_message,
    r.review_created_at,

    -- Derived business flags
    CASE WHEN o.order_status = 'delivered' THEN TRUE ELSE FALSE END AS is_delivered,
    CASE WHEN o.order_status = 'canceled'  THEN TRUE ELSE FALSE END AS is_canceled,

    -- Date dimensions for time-based analysis
    DATE(o.order_purchase_at)                   AS order_purchase_date,
    DATE_TRUNC('month', o.order_purchase_at)    AS order_purchase_month,
    DATE_TRUNC('quarter', o.order_purchase_at)  AS order_purchase_quarter,
    YEAR(o.order_purchase_at)                   AS order_purchase_year

FROM orders_enriched AS o
LEFT JOIN latest_review AS r
    ON o.order_id = r.order_id
