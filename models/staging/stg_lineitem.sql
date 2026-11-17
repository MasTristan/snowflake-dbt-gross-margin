select
    l_orderkey      as order_key,
    l_partkey       as part_key,
    l_suppkey       as supplier_key,
    l_linenumber    as line_number,
    l_quantity      as quantity,
    l_extendedprice as extended_price,
    l_discount      as discount_pct,
    l_tax           as tax_pct,
    l_shipdate      as ship_date,
    {{ calculate_net_revenue('l_extendedprice', 'l_discount') }} as net_revenue
from {{ source('tpch', 'lineitem') }}
qualify row_number() over (
    partition by l_orderkey, l_linenumber
    order by l_shipdate desc
) = 1