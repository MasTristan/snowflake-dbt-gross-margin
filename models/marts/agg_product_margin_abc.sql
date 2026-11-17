-- ABC / Pareto analysis of gross margin by product. Ranks products by total margin,
-- accumulates their share, and classes them A (up to 80% of cumulative margin), B
-- (up to 95%), C (the tail). Shows which minority of products drives most of the margin.
-- Note: products with a negative total margin sort last and can nudge the tail; a
-- production version would flag loss-making products separately.
with product_margin as (
    select
        fct_sales.part_key,
        dim_products.manufacturer,
        dim_products.brand,
        sum(fct_sales.gross_margin) as total_gross_margin
    from {{ ref('fct_sales') }} as fct_sales
    left join {{ ref('dim_products') }} as dim_products
        on fct_sales.part_key = dim_products.part_key
    group by
        fct_sales.part_key,
        dim_products.manufacturer,
        dim_products.brand
),

ranked as (
    select
        *,
        sum(total_gross_margin) over (
            order by total_gross_margin desc, part_key
            rows between unbounded preceding and current row
        ) as cumulative_margin,
        sum(total_gross_margin) over () as grand_total_margin
    from product_margin
)

select
    part_key,
    manufacturer,
    brand,
    total_gross_margin,
    cumulative_margin,
    round(cumulative_margin / nullif(grand_total_margin, 0), 4) as cumulative_margin_pct,
    case
        when cumulative_margin / nullif(grand_total_margin, 0) <= 0.80 then 'A'
        when cumulative_margin / nullif(grand_total_margin, 0) <= 0.95 then 'B'
        else 'C'
    end as abc_class
from ranked
