{# Grain: one row per event, day and ticket type. #}
select
    ts.event_date::date as event_date,
    (
        case
            when ts.event_code is null then '-1'
            else {{ md5_composite_keys('ts.event_code') }}
        end
    )::varchar as event_xid,
    (
        case
            when ev.venue_code is null then '-1'
            else {{ md5_composite_keys('ev.venue_code') }}
        end
    )::varchar as venue_xid,
    ts.ticket_type::varchar as ticket_type,
    ts.tickets_sold::number(38, 0) as tickets_sold,
from
    {{ ref('event__ticket_sales') }} as ts
left join
    {{ ref('event__event') }} as ev
    on
        ev.event_code = ts.event_code
