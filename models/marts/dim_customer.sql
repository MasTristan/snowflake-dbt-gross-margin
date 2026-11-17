with customers as (
    select
        customer_key,
        sha2(customer_name, 256) as customer_name_hashed,
        nation_key,
        market_segment
    from {{ ref('stg_customer') }}
),

nations as (
    select
        nation_key,
        nation_name,
        region_name
    from {{ ref('stg_nation') }}
),

customer_margin as (
    select
        customer_key,
        total_gross_margin
    from {{ ref('int_customer_margin') }}
),

joined as (
    select
        customers.customer_key,
        customers.customer_name_hashed,
        customers.market_segment,
        nations.nation_name,
        nations.region_name,
        -- customers with no sale get a zero margin so they land in the bottom tier
        coalesce(customer_margin.total_gross_margin, 0) as total_gross_margin
    from customers
    left join nations
        on customers.nation_key = nations.nation_key
    left join customer_margin
        on customers.customer_key = customer_margin.customer_key
),

ranked as (
    select
        *,
        ntile(5) over (order by total_gross_margin desc) as customer_margin_quintile
    from joined
)

select
    customer_key,
    customer_name_hashed,
    market_segment,
    nation_name,
    region_name,
    total_gross_margin,
    customer_margin_quintile,
    case customer_margin_quintile
        when 1 then 'Tier 1 (top 20%)'
        when 2 then 'Tier 2'
        when 3 then 'Tier 3'
        when 4 then 'Tier 4'
        when 5 then 'Tier 5 (bottom 20%)'
    end as customer_value_tier
from ranked
