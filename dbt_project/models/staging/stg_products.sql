-- Model: stg_products.sql
-- Layer: Staging
-- Description: Cleans raw product data. Casts physical dimensions and weight
--              to numeric. Handles NULL product categories gracefully.
-- Dependencies: RAW.OLIST_PRODUCTS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_products_dataset') }}
),

renamed AS (
    SELECT
        -- Primary key
        PRODUCT_ID      AS product_id,

        -- Category: NULL-safe — some products have no category in source
        -- COALESCE returns 'unknown' instead of NULL to avoid broken joins
        COALESCE(PRODUCT_CATEGORY_NAME, 'unknown') AS product_category_name,

        -- Description metrics: cast to INT
        CAST(PRODUCT_NAME_LENGHT AS INTEGER)        AS product_name_length,
        CAST(PRODUCT_DESCRIPTION_LENGHT AS INTEGER) AS product_description_length,
        CAST(PRODUCT_PHOTOS_QTY AS INTEGER)         AS product_photos_qty,

        -- Physical attributes: cast to FLOAT for calculations
        CAST(PRODUCT_WEIGHT_G AS FLOAT)       AS product_weight_g,
        CAST(PRODUCT_LENGTH_CM AS FLOAT)      AS product_length_cm,
        CAST(PRODUCT_HEIGHT_CM AS FLOAT)      AS product_height_cm,
        CAST(PRODUCT_WIDTH_CM AS FLOAT)       AS product_width_cm,

        -- Derived: cubic volume (useful for logistics/freight analysis)
        CAST(PRODUCT_LENGTH_CM AS FLOAT)
            * CAST(PRODUCT_HEIGHT_CM AS FLOAT)
            * CAST(PRODUCT_WIDTH_CM AS FLOAT) AS product_volume_cm3

    FROM source
)

SELECT * FROM renamed
