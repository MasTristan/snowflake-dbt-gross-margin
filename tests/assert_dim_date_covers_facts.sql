-- dim_date is generated with a hard-coded number of days. This test fails (returns a
-- row) if the generated range no longer covers every ship_date present in fct_sales.
with date_bounds as (
    select
        min(date_day) as min_date_day,
        max(date_day) as max_date_day
    from {{ ref('dim_date') }}
),

fact_bounds as (
    select
        min(ship_date) as min_ship_date,
        max(ship_date) as max_ship_date
    from {{ ref('fct_sales') }}
)

select
    date_bounds.min_date_day,
    date_bounds.max_date_day,
    fact_bounds.min_ship_date,
    fact_bounds.max_ship_date
from date_bounds
cross join fact_bounds
where date_bounds.min_date_day > fact_bounds.min_ship_date
   or date_bounds.max_date_day < fact_bounds.max_ship_date
