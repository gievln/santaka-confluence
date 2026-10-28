select
    ec.event_code::varchar as event_code,
    ec.cost_type::varchar as cost_type,
    ec.amount_eur::number(12, 2) as amount_eur,
from
    {{ ref('santaka_event_costs') }} as ec
