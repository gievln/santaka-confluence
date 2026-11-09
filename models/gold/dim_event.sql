{# Grain: one row per event, plus the '-1' unknown member. #}
select
    {{ md5_composite_keys('ev.event_code') }}::varchar as event_xid,
    ev.event_code::varchar as event_code,
    ev.event_name::varchar as event_name,
    ev.organiser_name::varchar as organiser_name,
    (
        case
            when ev.venue_code is null then '-1'
            else {{ md5_composite_keys('ev.venue_code') }}
        end
    )::varchar as venue_xid,
    ev.start_date::date as start_date,
    ev.end_date::date as end_date,
    ev.event_days::number(38, 0) as event_days,
    ev.is_festival::boolean as is_festival,
    ev.indoor_outdoor::varchar as indoor_outdoor,
    ev.capacity_per_day::number(38, 0) as capacity_per_day,
    ev.revenue_share_pct::number(10, 6) as revenue_share_pct,
    ev.share_basis::varchar as share_basis,
    ev.agreed_attribution_rule::varchar as agreed_attribution_rule,
from
    {{ ref('event__event') }} as ev

union all

select
    '-1'::varchar as event_xid,
    '-1'::varchar as event_code,
    'Unknown event'::varchar as event_name,
    'Unknown'::varchar as organiser_name,
    '-1'::varchar as venue_xid,
    null::date as start_date,
    null::date as end_date,
    null::number(38, 0) as event_days,
    null::boolean as is_festival,
    'Unknown'::varchar as indoor_outdoor,
    null::number(38, 0) as capacity_per_day,
    null::number(10, 6) as revenue_share_pct,
    null::varchar as share_basis,
    null::varchar as agreed_attribution_rule
