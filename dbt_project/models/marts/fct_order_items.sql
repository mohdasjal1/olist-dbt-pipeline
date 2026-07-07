-- Model: fct_order_items.sql
-- Layer: Mart (Fact Table)
-- Description: Fact table at the order-item level. One row per item sold.
--              Joins product and seller info for revenue analysis by category/seller.
--              WHY a separate fact table from fct_orders?
--              - fct_orders is order-level grain (1 row = 1 order)
--              - fct_order_items is item-level grain (1 row = 1 item)
--              - Different analytical questions require different grains.
--              - "Revenue by product category" needs item grain. fct_orders can't answer it.
-- Dependencies: stg_order_items, stg_orders, stg_products, stg_product_category, stg_sellers
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='table',
    schema='marts'
) }}

WITH order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

orders AS (
    SELECT
        order_id,
        order_status,
        order_purchase_at,
        customer_id

    FROM {{ ref('stg_orders') }}
),

products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

category_translation AS (
    SELECT * FROM {{ ref('stg_product_category') }}
),

sellers AS (
    SELECT * FROM {{ ref('stg_sellers') }}
)

SELECT
    -- Item identification
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,

    -- Order context
    o.order_status,
    o.order_purchase_at,
    o.customer_id,
    DATE(o.order_purchase_at)                   AS order_purchase_date,
    DATE_TRUNC('month', o.order_purchase_at)    AS order_purchase_month,

    -- Product details
    p.product_category_name                     AS product_category_name_pt,
    COALESCE(ct.product_category_name_en, p.product_category_name) AS product_category_name_en,
    p.product_weight_g,
    p.product_volume_cm3,

    -- Seller location
    s.seller_city,
    s.seller_state,

    -- Shipping
    oi.shipping_limit_at,

    -- Revenue metrics (answers "Which categories generate most revenue?")
    oi.item_price,
    oi.freight_value,
    oi.total_item_value,

    -- Flags
    CASE WHEN o.order_status = 'delivered' THEN TRUE ELSE FALSE END AS is_delivered,
    CASE WHEN o.order_status = 'canceled'  THEN TRUE ELSE FALSE END AS is_canceled

FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
LEFT JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name_pt
LEFT JOIN sellers AS s
    ON oi.seller_id = s.seller_id
