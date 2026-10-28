select
    co.event_code::varchar as event_code,
    co.revenue_share_pct::number(5, 4) as revenue_share_pct,
    co.share_basis::varchar as share_basis,
    co.signed_on::date as signed_on,
from
    {{ ref('santaka_contracts') }} as co
