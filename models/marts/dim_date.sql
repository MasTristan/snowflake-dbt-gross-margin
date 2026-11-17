-- Real date spine: one row per calendar day from the earliest order to the latest
-- shipment, so time intelligence has no gaps even for days with no activity. The
-- generator emits a fixed number of days that we then clip to the actual max date;
-- 5000 days (~13.7 years) comfortably covers the TPC-H 1992-1998 range. Coverage of
-- the fact dates and absence of gaps are enforced by tests/assert_dim_date_*.sql.
-- row_number() guarantees a gapless 0..n-1 offset, which seq4() alone does not.
--
-- is_complete_month flags months in the steady-state window of the data. Revenue and
-- margin are recognised on ship_date, which lags order_date by up to max_ship_lag_days.
-- A month is complete when it starts after the first orders have had time to ship
-- (min order_date + max lag) and ends before order intake stops (max order_date).
-- Months outside that window are ramp-up or run-off, not real business movement.
with bounds as (
    select
        (select min(order_date) from {{ ref('stg_orders') }})   as min_date,
        (select max(ship_date)  from {{ ref('stg_lineitem') }})  as max_date,
        (select max(order_date) from {{ ref('stg_orders') }})   as max_order_date,
        (
            select max(datediff(day, orders.order_date, lineitem.ship_date))
            from {{ ref('stg_lineitem') }} as lineitem
            inner join {{ ref('stg_orders') }} as orders
                on lineitem.order_key = orders.order_key
        )                                                        as max_ship_lag_days
),

spine as (
    select dateadd(day, row_number() over (order by seq4()) - 1, (select min_date from bounds)) as date_day
    from table(generator(rowcount => 5000))
)

select
    spine.date_day,
    year(spine.date_day)                as year,
    month(spine.date_day)               as month,
    day(spine.date_day)                 as day,
    to_char(spine.date_day, 'MMMM')     as month_name,
    quarter(spine.date_day)             as quarter,
    date_trunc('month', spine.date_day) as month_start,
    date_trunc('month', spine.date_day) >= dateadd(day, bounds.max_ship_lag_days, bounds.min_date)
        and last_day(spine.date_day) <= bounds.max_order_date as is_complete_month
from spine
cross join bounds
where spine.date_day <= bounds.max_date
