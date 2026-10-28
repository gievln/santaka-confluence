select
    rv.venue_code::varchar as venue_code,
    rv.venue_name::varchar as venue_name,
    rv.venue_type::varchar as venue_type,
    rv.city::varchar as city,
    rv.latitude::number(9, 6) as latitude,
    rv.longitude::number(9, 6) as longitude,
from
    {{ ref('ref_venues') }} as rv
