{# Resolves surrogate keys for fct_santaka_sales; '-1' when a business code is unknown (no-null FK rule). #}
select
    sl.sales_date,
    sl.sold_at,
    case
        when sl.event_code is null then '-1'
        else {{ md5_composite_keys('sl.event_code') }}
    end as event_xid,
    case
        when ev.venue_code is null then '-1'
        else {{ md5_composite_keys('ev.venue_code') }}
    end as venue_xid,
    case
        when sl.menu_item is null then '-1'
        else {{ md5_composite_keys('sl.menu_item') }}
    end as menu_item_xid,
    case
        when sl.santaka_sku is null then '-1'
        else {{ md5_composite_keys('sl.santaka_sku') }}
    end as product_xid,
    sl.epos_system_code,
    sl.transaction_id,
    sl.line_no,
    sl.line_type,
    sl.payment_method,
    sl.is_vip_voucher,
    sl.bar_no,
    sl.quantity,
    sl.santaka_ml_served,
    sl.attributed_sales_as_reported_volume_eur,
    sl.attributed_sales_as_reported_cost_eur,
    sl.attributed_sales_volume_eur,
    sl.attributed_sales_cost_eur,
    sl.revenue_share_volume_eur,
    sl.revenue_share_cost_eur,
    sl.cost_of_goods_eur,
from
    {{ ref('epos_sales__santaka_sales_line') }} as sl
left join
    {{ ref('event__event') }} as ev
    on
        ev.event_code = sl.event_code
