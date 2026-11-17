select
    p_partkey as part_key,
    p_name    as part_name,
    p_mfgr    as manufacturer,
    p_brand   as brand,
    p_type    as part_type
from {{ source('tpch', 'part') }}