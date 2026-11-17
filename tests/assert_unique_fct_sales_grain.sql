-- The declared grain of fct_sales is one row per order line (order_key + line_number).
-- This test proves that grain holds after the composite join on partsupp: a duplicate
-- (part_key, supplier_key) upstream would fan out the fact rows and silently inflate
-- gross_revenue / gross_margin. Returns any grain key that appears more than once.
select
    order_key,
    line_number,
    count(*) as row_count
from {{ ref('fct_sales') }}
group by order_key, line_number
having count(*) > 1
