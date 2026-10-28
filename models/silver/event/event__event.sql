{# One row per event with its venue code and contract terms. A festival is any event longer than one day. #}
select
    ev.event_code,
    ev.event_name,
    ev.organiser_name,
    ev.organiser_event_ref,
    rv.venue_code,
    ev.start_date,
    ev.end_date,
    datediff('day', ev.start_date, ev.end_date) + 1 as event_days,
    ev.end_date > ev.start_date as is_festival,
    ev.indoor_outdoor,
    ev.capacity_per_day,
    co.revenue_share_pct,
    co.share_basis,
    co.signed_on as contract_signed_on,
from
    {{ ref('santaka_crm__events') }} as ev
left join
    {{ ref('santaka_crm__contracts') }} as co
    on
        co.event_code = ev.event_code
left join
    {{ ref('ref_venues') }} as rv
    on
        rv.venue_name = ev.venue_name
