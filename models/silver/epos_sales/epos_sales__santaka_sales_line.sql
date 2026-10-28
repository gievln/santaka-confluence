{#
    One row per EPOS line and Santaka SKU in it; third-party items drop out here.
    Business rules:
      - attributed sales = what the organiser actually took, net of VAT, times Santaka's allocation
        (promo adjustments reduce it, VIP voucher redemptions contribute 0);
      - both attribution rules are carried, the contract does not say which applies;
      - revenue share = attributed sales * the event's contracted share;
      - cost of goods = Santaka litres served * production cost; promo lines serve nothing, vouchers do.
#}
with
    {# Keep only lines containing Santaka products; one row per line and Santaka SKU #}
    c_santaka_lines_step_10 as (
        select
            sl.epos_system_code,
            sl.transaction_id,
            sl.line_no,
            sl.line_type,
            sl.event_code,
            sl.sold_at,
            sl.sales_date,
            sl.bar_no,
            sl.menu_item,
            sl.payment_method,
            sl.quantity,
            sl.line_amount_as_reported,
            sl.line_amount_net,
            ma.santaka_sku,
            ma.santaka_ml_per_serve,
            ma.volume_allocation_pct,
            ma.cost_allocation_pct,
        from
            {{ ref('epos_sales__sales_line') }} as sl
        join
            {{ ref('recipe__menu_item_allocation') }} as ma
            on
                ma.menu_item = sl.menu_item
    ),
    {# Contracted revenue share and Santaka's production cost #}
    c_santaka_lines_step_20 as (
        select
            aa.*,
            ev.revenue_share_pct,
            pr.production_cost_eur_per_l,
        from
            c_santaka_lines_step_10 as aa
        join
            {{ ref('event__event') }} as ev
            on
                ev.event_code = aa.event_code
        join
            {{ ref('product__product') }} as pr
            on
                pr.sku = aa.santaka_sku
    ),
    {# Attribute takings to Santaka under both rules and work out litres poured #}
    c_santaka_lines_step_30 as (
        select
            aa.*,
            aa.line_amount_net * aa.volume_allocation_pct as v_attributed_sales_volume_eur,
            aa.line_amount_net * aa.cost_allocation_pct as v_attributed_sales_cost_eur,
            iff(aa.line_type = 'sale', aa.quantity * aa.santaka_ml_per_serve, 0) as v_santaka_ml_served,
        from
            c_santaka_lines_step_20 as aa
    )
select
    aa.epos_system_code,
    aa.transaction_id,
    aa.line_no,
    aa.santaka_sku,
    aa.line_type,
    aa.event_code,
    aa.sold_at,
    aa.sales_date,
    aa.bar_no,
    aa.menu_item,
    aa.payment_method,
    aa.payment_method = 'vip_voucher' as is_vip_voucher,
    aa.quantity,
    aa.volume_allocation_pct,
    aa.cost_allocation_pct,
    aa.revenue_share_pct,
    round(aa.line_amount_as_reported * aa.volume_allocation_pct, 4) as attributed_sales_as_reported_volume_eur,
    round(aa.line_amount_as_reported * aa.cost_allocation_pct, 4) as attributed_sales_as_reported_cost_eur,
    round(aa.v_attributed_sales_volume_eur, 4) as attributed_sales_volume_eur,
    round(aa.v_attributed_sales_cost_eur, 4) as attributed_sales_cost_eur,
    round(aa.v_attributed_sales_volume_eur * aa.revenue_share_pct, 4) as revenue_share_volume_eur,
    round(aa.v_attributed_sales_cost_eur * aa.revenue_share_pct, 4) as revenue_share_cost_eur,
    aa.v_santaka_ml_served as santaka_ml_served,
    round(aa.v_santaka_ml_served / 1000 * aa.production_cost_eur_per_l, 4) as cost_of_goods_eur,
from
    c_santaka_lines_step_30 as aa
