with nation as (
    select
        n_nationkey as nation_key,
        n_name      as nation_name,
        n_regionkey as region_key
    from {{ source('tpch', 'nation') }}
),

region as (
    select
        r_regionkey as region_key,
        r_name      as region_name
    from {{ source('tpch', 'region') }}
)

select
    nation.nation_key,
    nation.nation_name,
    region.region_name
from nation
left join region on nation.region_key = region.region_key