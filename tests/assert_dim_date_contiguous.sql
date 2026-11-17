-- dim_date must hold exactly one row per calendar day between its first and last day.
-- Returns a row if any day is missing (or duplicated).
select
    count(*)                                          as row_count,
    datediff(day, min(date_day), max(date_day)) + 1   as expected_days
from {{ ref('dim_date') }}
having count(*) != datediff(day, min(date_day), max(date_day)) + 1
