-- net_revenue = extended_price * (1 - discount_pct). A NULL discount is defended at
-- runtime by coalesce in the calculate_net_revenue macro, but it still signals a data
-- quality problem worth flagging. A discount outside [0, 1] would produce a negative or
-- inflated revenue. This test catches both cases before they reach the margin.
select
    order_key,
    line_number,
    discount_pct
from {{ ref('stg_lineitem') }}
where discount_pct is null
   or discount_pct < 0
   or discount_pct > 1
