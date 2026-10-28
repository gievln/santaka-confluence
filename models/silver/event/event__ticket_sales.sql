select
    ev.event_code,
    ts.event_date,
    ts.ticket_type,
    ts.tickets_sold,
from
    {{ ref('organiser__ticket_sales') }} as ts
left join
    {{ ref('santaka_crm__events') }} as ev
    on
        ev.organiser_event_ref = ts.organiser_event_ref
