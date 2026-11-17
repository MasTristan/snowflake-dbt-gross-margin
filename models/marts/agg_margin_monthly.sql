-- Monthly gross margin with month-over-month, year-over-year and a 3-month moving
-- average. A calendar month spine (from dim_date, bounded by the first and last ship
-- month in fct_sales) is left joined to the monthly totals, so a month without sales
-- appears with zero margin and revenue. lag(1) and lag(12) are therefore true calendar
-- shifts, and the 3-month window covers three consecutive calendar months.
-- is_complete_month comes from dim_date (single definition): months outside the
-- steady-state window are ramp-up or run-off and should be hidden from KPIs and trends.
-- Percent changes are NULL when the base is zero or missing.
with ship_bounds as (
    select
        min(ship_date) as min_ship_date,
        max(ship_date) as max_ship_date
    from {{ ref('fct_sales') }}
),

month_spine as (
    select distinct
        dim_date.month_start,
        dim_date.is_complete_month
    from {{ ref('dim_date') }} as dim_date
    cross join ship_bounds
    where date_trunc('month', dim_date.date_day)
        between date_trunc('month', ship_bounds.min_ship_date)
            and date_trunc('month', ship_bounds.max_ship_date)
),

monthly as (
    select
        date_trunc('month', ship_date) as month_start,
        sum(gross_margin)  as total_gross_margin,
        sum(gross_revenue) as total_gross_revenue
    from {{ ref('fct_sales') }}
    group by date_trunc('month', ship_date)
),

filled as (
    select
        month_spine.month_start,
        month_spine.is_complete_month,
        coalesce(monthly.total_gross_margin, 0)  as total_gross_margin,
        coalesce(monthly.total_gross_revenue, 0) as total_gross_revenue
    from month_spine
    left join monthly
        on month_spine.month_start = monthly.month_start
)

select
    filled.month_start,
    filled.total_gross_margin,
    filled.total_gross_revenue,
    filled.is_complete_month,
    lag(filled.total_gross_margin, 1) over (order by filled.month_start)  as prev_month_margin,
    lag(filled.total_gross_margin, 12) over (order by filled.month_start) as prev_year_margin,
    (
        filled.total_gross_margin - lag(filled.total_gross_margin, 1) over (order by filled.month_start)
    ) / nullif(lag(filled.total_gross_margin, 1) over (order by filled.month_start), 0) as mom_margin_pct,
    (
        filled.total_gross_margin - lag(filled.total_gross_margin, 12) over (order by filled.month_start)
    ) / nullif(lag(filled.total_gross_margin, 12) over (order by filled.month_start), 0) as yoy_margin_pct,
    avg(filled.total_gross_margin) over (
        order by filled.month_start
        rows between 2 preceding and current row
    ) as margin_3mo_moving_avg
from filled
