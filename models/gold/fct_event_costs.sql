{# Grain: one row per event and cost type. #}
select
    (
        case
            when ec.event_code is null then '-1'
            else {{ md5_composite_keys('ec.event_code') }}
        end
    )::varchar as event_xid,
    ec.cost_type::varchar as cost_type,
    ec.amount_eur::number(14, 2) as amount_eur,
from
    {{ ref('event__cost') }} as ec
