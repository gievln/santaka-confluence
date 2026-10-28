{# Grain: one row per event. Santaka's profit under both attribution rules. #}
select
    {{ md5_composite_keys('ep.event_code') }}::varchar as event_xid,
    (
        case
            when ev.venue_code is null then '-1'
            else {{ md5_composite_keys('ev.venue_code') }}
        end
    )::varchar as venue_xid,
    ep.attributed_sales_volume_eur::number(14, 4) as attributed_sales_volume_eur,
    ep.attributed_sales_cost_eur::number(14, 4) as attributed_sales_cost_eur,
    ep.revenue_share_volume_eur::number(14, 4) as revenue_share_volume_eur,
    ep.revenue_share_cost_eur::number(14, 4) as revenue_share_cost_eur,
    ep.cost_of_goods_eur::number(14, 4) as cost_of_goods_eur,
    ep.event_costs_eur::number(14, 2) as event_costs_eur,
    ep.profit_volume_eur::number(14, 4) as profit_volume_eur,
    ep.profit_cost_eur::number(14, 4) as profit_cost_eur,
    ep.santaka_litres_served::number(14, 2) as santaka_litres_served,
    ep.tickets_sold::number(38, 0) as tickets_sold,
from
    {{ ref('event__profit') }} as ep
left join
    {{ ref('event__event') }} as ev
    on
        ev.event_code = ep.event_code
