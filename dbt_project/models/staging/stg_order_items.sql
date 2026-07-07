-- Model: stg_order_items.sql
-- Layer: Staging
-- Description: Cleans raw order items — the line-item detail of every order.
--              Each order can have multiple items. Casts monetary values to FLOAT.
-- Dependencies: RAW.OLIST_ORDER_ITEMS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_order_items_dataset') }}
),

renamed AS (
    SELECT
        -- Composite primary key (order_id + order_item_id together are unique)
        ORDER_ID AS order_id,
        ORDER_ITEM_ID AS order_item_id,

        -- Foreign keys
        PRODUCT_ID AS product_id,
        SELLER_ID   AS seller_id,

        -- Shipping limit: cast to timestamp for delivery analysis
        TRY_CAST(SHIPPING_LIMIT_DATE AS TIMESTAMP_NTZ) AS shipping_limit_at,

        -- Monetary: cast to FLOAT for arithmetic
        -- WHY FLOAT not DECIMAL? Snowflake arithmetic with FLOAT is faster for aggregations.
        -- For financial reporting requiring exact precision, use NUMBER(10,2).
        TRY_CAST(PRICE AS FLOAT)          AS item_price,
        TRY_CAST(FREIGHT_VALUE AS FLOAT)  AS freight_value,

        -- Derived metric useful for downstream analysis
        TRY_CAST(PRICE AS FLOAT) + TRY_CAST(FREIGHT_VALUE AS FLOAT) AS total_item_value

    FROM source
)

SELECT * FROM renamed
