-- A gross revenue less than or equal to zero is a business anomaly worth flagging.
select
    order_key,
    line_number,
    gross_revenue
from {{ ref('fct_sales') }}
where gross_revenue <= 0
