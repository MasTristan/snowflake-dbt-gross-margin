-- Total gross margin and volume per customer. Ephemeral: it exists only to keep the
-- customer-level rollup DRY between dim_customer (value tier) and any future customer
-- aggregate, without materializing an object we never query directly.
select
    customer_key,
    sum(gross_margin)  as total_gross_margin,
    sum(gross_revenue) as total_gross_revenue,
    count(*)           as order_line_count
from {{ ref('fct_sales') }}
group by customer_key
