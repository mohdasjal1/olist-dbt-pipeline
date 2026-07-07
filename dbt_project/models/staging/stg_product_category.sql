-- Model: stg_product_category.sql
-- Layer: Staging
-- Description: Translation table mapping Portuguese product category names
--              to English. Joined to stg_products and mart layer for
--              English-readable category analytics.
-- Dependencies: RAW.PRODUCT_CATEGORY_NAME_TRANSLATION
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'product_category_name_translation') }}
),

renamed AS (
    SELECT
        PRODUCT_CATEGORY_NAME         AS product_category_name_pt,  -- Portuguese (source)
        PRODUCT_CATEGORY_NAME_ENGLISH AS product_category_name_en   -- English (for reporting)

    FROM source
)

SELECT * FROM renamed
