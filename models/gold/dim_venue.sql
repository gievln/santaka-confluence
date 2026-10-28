{# Grain: one row per venue, plus the '-1' unknown member. Conformed across sales, tickets and weather. #}
select
    {{ md5_composite_keys('vn.venue_code') }}::varchar as venue_xid,
    vn.venue_code::varchar as venue_code,
    vn.venue_name::varchar as venue_name,
    vn.venue_type::varchar as venue_type,
    vn.city::varchar as city,
    vn.latitude::number(9, 6) as latitude,
    vn.longitude::number(9, 6) as longitude,
from
    {{ ref('event__venue') }} as vn

union all

select
    '-1'::varchar as venue_xid,
    '-1'::varchar as venue_code,
    'Unknown venue'::varchar as venue_name,
    'Unknown'::varchar as venue_type,
    null::varchar as city,
    null::number(9, 6) as latitude,
    null::number(9, 6) as longitude
