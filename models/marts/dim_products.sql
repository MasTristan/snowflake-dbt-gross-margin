with parts as (
    select
        part_key,
        part_name,
        manufacturer,
        brand,
        part_type
    from {{ ref('stg_part') }}
)

select
    part_key,
    part_name,
    manufacturer,
    brand,
    part_type
from parts