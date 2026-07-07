-- Model: stg_geolocation.sql
-- Layer: Staging
-- Description: Cleans geolocation data mapping Brazilian zip code prefixes to
--              lat/lng coordinates. This table has ~1M rows (many per zip code).
--              We deduplicate to one row per zip code prefix (median lat/lng).
-- Dependencies: RAW.OLIST_GEOLOCATION_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_geolocation_dataset') }}
),

renamed AS (
    SELECT
        GEOLOCATION_ZIP_CODE_PREFIX AS zip_code_prefix,
        TRY_CAST(GEOLOCATION_LAT AS FLOAT) AS latitude,
        TRY_CAST(GEOLOCATION_LNG AS FLOAT) AS longitude,
        UPPER(GEOLOCATION_CITY)  AS city,
        UPPER(GEOLOCATION_STATE) AS state

    FROM source
),

-- WHY deduplication here?
-- The raw geolocation table has multiple lat/lng rows per zip code (different streets).
-- Downstream joins (customer -> geolocation) need exactly ONE row per zip code.
-- We use QUALIFY with ROW_NUMBER to pick the first occurrence per zip code.
-- Alternative: use AVG(lat), AVG(lng) — we use first-row approach for simplicity.
deduplicated AS (
    SELECT
        zip_code_prefix,
        latitude,
        longitude,
        city,
        state,
        ROW_NUMBER() OVER (PARTITION BY zip_code_prefix ORDER BY zip_code_prefix) AS rn

    FROM renamed
)

SELECT
    zip_code_prefix,
    latitude,
    longitude,
    city,
    state

FROM deduplicated
WHERE rn = 1
