-- Model: int_orders_enriched.sql
-- Layer: Intermediate
-- Description: Enriches orders with customer location and payment summary.
--              Calculates key delivery time metrics used in mart layer.
--              This is the central enriched order dataset that fct_orders is built from.
-- Dependencies: stg_orders, stg_customers, stg_payments
-- Author: Mohammad Asjad
-- Last Updated: 2026-07-07

{{ config(
    materialized='view',
    schema='intermediate'
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

-- Aggregate payments to order level (one row per order)
-- WHY aggregate here? stg_payments has one row per payment method.
-- For order-level analysis, we want total_payment_value and primary payment type.
payment_summary AS (
    SELECT
        order_id,
        SUM(payment_value)                              AS total_payment_value,
        COUNT(DISTINCT payment_type)                    AS payment_type_count,
        -- Primary payment type = the one with highest value
        MAX(CASE WHEN payment_value = max_payment
                 THEN payment_type END)                 AS primary_payment_type,
        SUM(payment_installments)                       AS total_installments

    FROM (
        SELECT
            order_id,
            payment_type,
            payment_value,
            payment_installments,
            MAX(payment_value) OVER (PARTITION BY order_id) AS max_payment

        FROM {{ ref('stg_payments') }}
    ) AS payments_with_max

    GROUP BY order_id
),

enriched AS (
    SELECT
        -- Order identifiers
        o.order_id,
        o.customer_id,

        -- Order status
        o.order_status,

        -- Order timestamps
        o.order_purchase_at,
        o.order_approved_at,
        o.order_delivered_to_carrier_at,
        o.order_delivered_to_customer_at,
        o.order_estimated_delivery_at,

        -- Delivery time metrics (in days)
        -- WHY DATEDIFF here vs. in mart? Keeps mart clean — all calculations in intermediate.
        DATEDIFF('day', o.order_purchase_at, o.order_delivered_to_customer_at)
            AS actual_delivery_days,

        DATEDIFF('day', o.order_purchase_at, o.order_estimated_delivery_at)
            AS estimated_delivery_days,

        -- Was the delivery on time?
        CASE
            WHEN o.order_delivered_to_customer_at <= o.order_estimated_delivery_at THEN TRUE
            ELSE FALSE
        END AS is_delivered_on_time,

        -- Days late (negative = early delivery)
        DATEDIFF('day', o.order_estimated_delivery_at, o.order_delivered_to_customer_at)
            AS delivery_delay_days,

        -- Customer location
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.customer_zip_code_prefix,

        -- Payment summary (COALESCE handles orders with no payment records)
        COALESCE(ps.total_payment_value, 0) AS total_payment_value,
        ps.primary_payment_type,
        COALESCE(ps.payment_type_count, 0) AS payment_type_count,
        COALESCE(ps.total_installments, 0) AS total_installments

    FROM orders AS o
    LEFT JOIN customers AS c
        ON o.customer_id = c.customer_id

    LEFT JOIN payment_summary AS ps
        ON o.order_id = ps.order_id
)

SELECT * FROM enriched
