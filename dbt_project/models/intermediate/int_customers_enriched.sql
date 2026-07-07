-- Model: int_customers_enriched.sql
-- Layer: Intermediate
-- Description: Enriches customer data with full geolocation details.
--              Maps zip code prefix to lat/lng coordinates for geographic analysis.
--              Powers dim_customers and geographic breakdowns in fct_orders.
-- Dependencies: stg_customers, stg_geolocation
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

geolocation AS (
    SELECT * FROM {{ ref('stg_geolocation') }}
),

enriched AS (
    SELECT
        c.customer_id,
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,

        -- Geolocation fields (NULL-safe: not all zip codes have geo data)
        g.latitude  AS customer_latitude,
        g.longitude AS customer_longitude,

        -- WHY LEFT JOIN not INNER JOIN?
        -- Some customer zip codes may not exist in geolocation table.
        -- INNER JOIN would silently drop those customers from all downstream marts.
        -- LEFT JOIN preserves all customers, with NULL geo for unmatched zips.
        COALESCE(g.city, c.customer_city)       AS geo_city,
        COALESCE(g.state, c.customer_state)     AS geo_state

    FROM customers AS c
    LEFT JOIN geolocation AS g
        ON c.customer_zip_code_prefix = g.zip_code_prefix
)

SELECT * FROM enriched
