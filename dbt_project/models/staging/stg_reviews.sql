-- Model: stg_reviews.sql
-- Layer: Staging
-- Description: Cleans customer review data. Review score is on a 1-5 scale.
--              Text comments are optional — NULLs handled with COALESCE.
-- Dependencies: RAW.OLIST_ORDER_REVIEWS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_order_reviews_dataset') }}
),

renamed AS (
    SELECT
        REVIEW_ID   AS review_id,
        ORDER_ID    AS order_id,

        -- Score: 1-5, cast to integer for aggregations
        TRY_CAST(REVIEW_SCORE AS INTEGER) AS review_score,

        -- Text fields: NULL-safe
        COALESCE(REVIEW_COMMENT_TITLE, '') AS review_comment_title,
        COALESCE(REVIEW_COMMENT_MESSAGE, '') AS review_comment_message,

        -- Timestamps
        TRY_CAST(REVIEW_CREATION_DATE AS TIMESTAMP_NTZ)    AS review_created_at,
        TRY_CAST(REVIEW_ANSWER_TIMESTAMP AS TIMESTAMP_NTZ) AS review_answered_at,

        -- Derived: response time in hours (customer service metric)
        DATEDIFF(
            'hour',
            TRY_CAST(REVIEW_CREATION_DATE AS TIMESTAMP_NTZ),
            TRY_CAST(REVIEW_ANSWER_TIMESTAMP AS TIMESTAMP_NTZ)
        ) AS review_response_hours

    FROM source
)

SELECT * FROM renamed
