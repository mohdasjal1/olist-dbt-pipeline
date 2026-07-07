-- Model: stg_sellers.sql
-- Layer: Staging
-- Description: Cleans seller data. Sellers are merchants who list on Olist marketplace.
--              Standardizes state codes and city names for geographic analysis.
-- Dependencies: RAW.OLIST_SELLERS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_sellers_dataset') }}
),

renamed AS (
    SELECT
        SELLER_ID               AS seller_id,
        SELLER_ZIP_CODE_PREFIX  AS seller_zip_code_prefix,
        UPPER(SELLER_CITY)      AS seller_city,
        UPPER(SELLER_STATE)     AS seller_state

    FROM source
)

SELECT * FROM renamed
