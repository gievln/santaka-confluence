select
    ts.organiser_event_ref::varchar as organiser_event_ref,
    ts.event_date::date as event_date,
    ts.ticket_type::varchar as ticket_type,
    ts.tickets_sold::integer as tickets_sold,
from
    {{ ref('organiser_ticket_sales') }} as ts
