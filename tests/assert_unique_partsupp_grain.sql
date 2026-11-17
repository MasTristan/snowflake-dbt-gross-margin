-- stg_partsupp is joined into fct_sales on the composite key (part_key, supplier_key)
-- to bring in supply_cost. If that pair is not unique, the join fans out the fact table
-- and corrupts the margin. This guards the assumption at the source of the join.
select
    part_key,
    supplier_key,
    count(*) as row_count
from {{ ref('stg_partsupp') }}
group by part_key, supplier_key
having count(*) > 1
