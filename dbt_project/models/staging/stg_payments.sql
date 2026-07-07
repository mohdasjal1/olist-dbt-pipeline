-- Model: stg_payments.sql
-- Layer: Staging
-- Description: Cleans payment data. An order can have multiple payments
--              (e.g., part credit card, part voucher). payment_sequential
--              identifies the payment installment order.
-- Dependencies: RAW.OLIST_ORDER_PAYMENTS_DATASET
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='staging'
) }}

WITH source AS (
    SELECT * FROM {{ source('olist_raw', 'olist_order_payments_dataset') }}
),

renamed AS (
    SELECT
        -- Composite key: one order may have multiple payment rows
        ORDER_ID            AS order_id,
        TRY_CAST(PAYMENT_SEQUENTIAL AS INTEGER) AS payment_sequential,

        -- Payment type: tested with accepted_values in schema.yml
        PAYMENT_TYPE        AS payment_type,

        -- Installments: Brazilian credit culture = heavy installment use
        -- WHY important? Installments affect merchant cash flow analysis
        TRY_CAST(PAYMENT_INSTALLMENTS AS INTEGER) AS payment_installments,

        -- Value: cast to FLOAT
        TRY_CAST(PAYMENT_VALUE AS FLOAT) AS payment_value

    FROM source
)

SELECT * FROM renamed
