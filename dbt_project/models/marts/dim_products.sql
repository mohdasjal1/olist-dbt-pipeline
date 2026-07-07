-- Model: dim_products.sql
-- Layer: Mart (Dimension Table)
-- Description: Product dimension. One row per product with English category name,
--              physical attributes, and sales performance summary.
-- Dependencies: stg_products, stg_product_category, stg_order_items
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='table',
    schema='marts'
) }}

WITH products AS (
    SELECT * FROM {{ ref('stg_products') }}
),

category_translation AS (
    SELECT * FROM {{ ref('stg_product_category') }}
),

product_sales AS (
    SELECT
        product_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(item_price)          AS total_revenue,
        AVG(item_price)          AS avg_selling_price,
        COUNT(*)                 AS total_items_sold

    FROM {{ ref('stg_order_items') }}
    GROUP BY product_id
)

SELECT
    p.product_id,

    -- Category in both languages
    p.product_category_name                                         AS category_name_pt,
    COALESCE(ct.product_category_name_en, p.product_category_name) AS category_name_en,

    -- Physical attributes
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volume_cm3,

    -- Content metrics
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,

    -- Sales performance
    COALESCE(ps.total_orders, 0)      AS total_orders,
    COALESCE(ps.total_items_sold, 0)  AS total_items_sold,
    COALESCE(ps.total_revenue, 0)     AS total_revenue,
    ps.avg_selling_price

FROM products AS p
LEFT JOIN category_translation AS ct
    ON p.product_category_name = ct.product_category_name_pt
LEFT JOIN product_sales AS ps
    ON p.product_id = ps.product_id
