-- Model: dim_sellers.sql
-- Layer: Mart (Dimension Table)
-- Description: Seller dimension with full performance KPIs.
--              One row per seller. Answers: "Which sellers have highest cancellation rates?"
-- Dependencies: int_sellers_performance
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='table',
    schema='marts'
) }}

SELECT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix,

    -- Performance KPIs
    total_orders,
    total_items_sold,
    unique_products_sold,
    total_revenue,
    total_freight_charged,
    avg_item_price,
    cancellation_rate_pct,

    -- Review performance
    avg_review_score,
    total_reviews,

    -- Classification
    seller_tier

FROM {{ ref('int_sellers_performance') }}
