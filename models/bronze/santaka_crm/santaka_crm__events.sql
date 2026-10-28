select
    ev.event_code::varchar as event_code,
    ev.event_name::varchar as event_name,
    ev.organiser_name::varchar as organiser_name,
    ev.organiser_event_ref::varchar as organiser_event_ref,
    ev.venue::varchar as venue_name,
    ev.city::varchar as city,
    ev.start_date::date as start_date,
    ev.end_date::date as end_date,
    ev.indoor_outdoor::varchar as indoor_outdoor,
    ev.capacity_per_day::integer as capacity_per_day,
from
    {{ ref('santaka_events') }} as ev
