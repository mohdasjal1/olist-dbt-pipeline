-- Model: stg_customers.sql
-- Layer: Staging
-- Description: Cleans raw customer data. Note: in Olist, each order has a unique
--              customer_id — so one physical customer can appear multiple times
--              with different customer_id values. customer_unique_id is the real
--              dedup key. Both are preserved here for downstream use.
-- Dependencies: RAW.OLIST_CUSTOMERS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

--testing ci/cd

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_customers_dataset') }}
),

renamed AS (
    SELECT
        -- customer_id: order-scoped ID (foreign key in orders table)
        CUSTOMER_ID         AS customer_id,

        -- customer_unique_id: actual person-level unique identifier
        -- WHY both? Olist creates a new customer_id per order for privacy.
        -- For cohort analysis and repeat purchase analysis, use customer_unique_id.
        CUSTOMER_UNIQUE_ID  AS customer_unique_id,

        -- Location: used for geographic analysis
        CUSTOMER_ZIP_CODE_PREFIX    AS customer_zip_code_prefix,
        UPPER(CUSTOMER_CITY)        AS customer_city,    -- Standardize to uppercase
        UPPER(CUSTOMER_STATE)       AS customer_state    -- 2-letter state code, uppercase

    FROM source
)

SELECT * FROM renamed
