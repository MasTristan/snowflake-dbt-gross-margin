-- Grain: one row per order line (order_key, line_number).
-- Incremental merge on that key, reloading the last `lookback_days` days before the
-- current max ship_date, so late-arriving lines are absorbed without duplicates.
-- Changes to supply_cost or order_status on lines already loaded are NOT propagated:
-- run a scheduled `dbt run --full-refresh -s fct_sales` to realign history.
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['order_key', 'line_number'],
    on_schema_change='append_new_columns'
) }}

with lineitem as (
    select
        order_key,
        part_key,
        supplier_key,
        line_number,
        quantity,
        extended_price,
        discount_pct,
        ship_date,
        net_revenue
    from {{ ref('stg_lineitem') }}

    {% if is_incremental() %}
    where ship_date >= (
        select dateadd(day, -{{ var('lookback_days', 3) }}, coalesce(max(ship_date), '1900-01-01'::date))
        from {{ this }}
    )
    {% endif %}
),

orders as (
    select
        order_key,
        customer_key,
        order_status,
        order_date
    from {{ ref('stg_orders') }}
),

partsupp as (
    select
        part_key,
        supplier_key,
        supply_cost
    from {{ ref('stg_partsupp') }}
)

select
    -- keys
    lineitem.order_key,
    lineitem.line_number,
    orders.customer_key,
    lineitem.part_key,

    -- dates
    lineitem.ship_date,
    orders.order_date,

    -- order attributes
    orders.order_status,

    -- measures
    lineitem.quantity,
    lineitem.net_revenue                                        as gross_revenue,
    partsupp.supply_cost * lineitem.quantity                   as gross_cost,
    lineitem.net_revenue
        - (partsupp.supply_cost * lineitem.quantity)           as gross_margin,
    (
        lineitem.net_revenue
            - (partsupp.supply_cost * lineitem.quantity)
    ) / nullif(lineitem.net_revenue, 0)                        as gross_margin_pct

from lineitem
left join orders
    on lineitem.order_key = orders.order_key
left join partsupp
    on  lineitem.part_key     = partsupp.part_key
    and lineitem.supplier_key = partsupp.supplier_key