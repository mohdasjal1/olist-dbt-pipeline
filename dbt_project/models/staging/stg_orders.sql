-- Model: stg_orders.sql
-- Layer: Staging
-- Description: Cleans and standardizes raw orders data from Olist source.
--              Casts all timestamp columns, renames to snake_case, and
--              ensures status values are valid before downstream joins.
-- Dependencies: RAW.OLIST_ORDERS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    -- Reference raw source — dbt tracks lineage automatically
    SELECT * FROM {{ source('olist_raw', 'olist_orders_dataset') }}
),

renamed AS (
    SELECT
        -- Primary key
        ORDER_ID AS order_id,

        -- Foreign keys
        CUSTOMER_ID AS customer_id,

        -- Status: kept as-is from source, tested via accepted_values
        ORDER_STATUS AS order_status,

        -- Timestamps: cast VARCHAR -> TIMESTAMP for date arithmetic downstream
        -- WHY TRY_CAST: Source data has occasional malformed dates.
        --               TRY_CAST returns NULL instead of failing the entire model.
        TRY_CAST(ORDER_PURCHASE_TIMESTAMP AS TIMESTAMP_NTZ) AS order_purchase_at,
        TRY_CAST(ORDER_APPROVED_AT AS TIMESTAMP_NTZ)        AS order_approved_at,
        TRY_CAST(ORDER_DELIVERED_CARRIER_DATE AS TIMESTAMP_NTZ) AS order_delivered_to_carrier_at,
        TRY_CAST(ORDER_DELIVERED_CUSTOMER_DATE AS TIMESTAMP_NTZ) AS order_delivered_to_customer_at,
        TRY_CAST(ORDER_ESTIMATED_DELIVERY_DATE AS TIMESTAMP_NTZ) AS order_estimated_delivery_at

    FROM source
)

SELECT * FROM renamed
