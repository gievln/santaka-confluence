{#
    One row per event: Santaka's revenue share, cost of goods, own event costs and profit under both attribution rules.
    Business rule: profit = revenue share - cost of goods - event costs (logistics, staff, branding, listing fee).
#}
with
    {# Santaka's sales side per event #}
    c_event_sales_step_10 as (
        select
            ss.event_code,
            sum(ss.attributed_sales_volume_eur) as attributed_sales_volume_eur_sum,
            sum(ss.attributed_sales_cost_eur) as attributed_sales_cost_eur_sum,
            sum(ss.revenue_share_volume_eur) as revenue_share_volume_eur_sum,
            sum(ss.revenue_share_cost_eur) as revenue_share_cost_eur_sum,
            sum(ss.cost_of_goods_eur) as cost_of_goods_eur_sum,
            sum(ss.santaka_ml_served) / 1000 as santaka_litres_served_sum,
        from
            {{ ref('epos_sales__santaka_sales_line') }} as ss
        group by
            ss.event_code
    ),
    {# Santaka's own costs per event #}
    c_event_costs_step_20 as (
        select
            ec.event_code,
            sum(ec.amount_eur) as event_costs_eur_sum,
        from
            {{ ref('event__cost') }} as ec
        group by
            ec.event_code
    ),
    {# Attendance per event, all days and ticket types #}
    c_event_tickets_step_30 as (
        select
            ts.event_code,
            sum(ts.tickets_sold) as tickets_sold_sum,
        from
            {{ ref('event__ticket_sales') }} as ts
        group by
            ts.event_code
    )
select
    ev.event_code,
    coalesce(aa.attributed_sales_volume_eur_sum, 0) as attributed_sales_volume_eur,
    coalesce(aa.attributed_sales_cost_eur_sum, 0) as attributed_sales_cost_eur,
    coalesce(aa.revenue_share_volume_eur_sum, 0) as revenue_share_volume_eur,
    coalesce(aa.revenue_share_cost_eur_sum, 0) as revenue_share_cost_eur,
    coalesce(aa.cost_of_goods_eur_sum, 0) as cost_of_goods_eur,
    coalesce(bb.event_costs_eur_sum, 0) as event_costs_eur,
    (
        revenue_share_volume_eur -
        cost_of_goods_eur -
        event_costs_eur
    ) as profit_volume_eur,
    (
        revenue_share_cost_eur -
        cost_of_goods_eur -
        event_costs_eur
    ) as profit_cost_eur,
    coalesce(aa.santaka_litres_served_sum, 0) as santaka_litres_served,
    coalesce(cc.tickets_sold_sum, 0) as tickets_sold,
from
    {{ ref('event__event') }} as ev
left join
    c_event_sales_step_10 as aa
    on
        aa.event_code = ev.event_code
left join
    c_event_costs_step_20 as bb
    on
        bb.event_code = ev.event_code
left join
    c_event_tickets_step_30 as cc
    on
        cc.event_code = ev.event_code
