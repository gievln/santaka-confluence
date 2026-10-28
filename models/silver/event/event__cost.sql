select
    ec.event_code,
    ec.cost_type,
    ec.amount_eur,
from
    {{ ref('santaka_erp__event_costs') }} as ec
