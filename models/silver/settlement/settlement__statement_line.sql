{# One row per organiser statement line: event and menu item, with the share as a fraction rather than percentage points. #}
select
    ev.event_code,
    ss.organiser_event_ref,
    ss.issued_on,
    mi.menu_item,
    ss.item_description,
    ss.quantity_sold,
    ss.attributed_sales_net_eur,
    ss.revenue_share_pct_points / 100 as revenue_share_pct,
    ss.payable_eur,
from
    {{ ref('organiser__settlement_statement') }} as ss
left join
    {{ ref('santaka_crm__events') }} as ev
    on
        ev.organiser_event_ref = ss.organiser_event_ref
left join
    {{ ref('product__menu_item') }} as mi
    on
        mi.menu_item = ss.item_description
