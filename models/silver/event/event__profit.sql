{#
    One row per event: Santaka's revenue share, cost of goods, own event costs and profit.
    Business rules:
      - profit = revenue share - cost of goods - event costs (logistics, staff, branding, listing fee);
      - profit_received uses the share the organiser's settlement statement actually pays (organiser applies the volume rule);
      - profit_volume / profit_cost are what Santaka's own data gives under each split rule;
      - profit_agreed_rule follows the contract's attribution rule and stays null while no rule is agreed.
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
    ),
    {# What the organiser's settlement statement pays Santaka per event #}
    c_event_statement_step_40 as (
        select
            st.event_code,
            sum(st.payable_eur) as revenue_share_received_eur_sum,
        from
            {{ ref('settlement__statement_line') }} as st
        group by
            st.event_code
    ),
    {# One row per event with every component, missing components as zero #}
    c_event_profit_step_50 as (
        select
            ev.event_code,
            ev.agreed_attribution_rule,
            coalesce(aa.attributed_sales_volume_eur_sum, 0) as attributed_sales_volume_eur,
            coalesce(aa.attributed_sales_cost_eur_sum, 0) as attributed_sales_cost_eur,
            coalesce(aa.revenue_share_volume_eur_sum, 0) as revenue_share_volume_eur,
            coalesce(aa.revenue_share_cost_eur_sum, 0) as revenue_share_cost_eur,
            coalesce(dd.revenue_share_received_eur_sum, 0) as revenue_share_received_eur,
            coalesce(aa.cost_of_goods_eur_sum, 0) as cost_of_goods_eur,
            coalesce(bb.event_costs_eur_sum, 0) as event_costs_eur,
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
        left join
            c_event_statement_step_40 as dd
            on
                dd.event_code = ev.event_code
    )
select
    aa.event_code,
    aa.agreed_attribution_rule,
    aa.attributed_sales_volume_eur,
    aa.attributed_sales_cost_eur,
    aa.revenue_share_volume_eur,
    aa.revenue_share_cost_eur,
    aa.revenue_share_received_eur,
    aa.cost_of_goods_eur,
    aa.event_costs_eur,
    (
        aa.revenue_share_volume_eur -
        aa.cost_of_goods_eur -
        aa.event_costs_eur
    ) as profit_volume_eur,
    (
        aa.revenue_share_cost_eur -
        aa.cost_of_goods_eur -
        aa.event_costs_eur
    ) as profit_cost_eur,
    (
        aa.revenue_share_received_eur -
        aa.cost_of_goods_eur -
        aa.event_costs_eur
    ) as profit_received_eur,
    case
        when aa.agreed_attribution_rule = 'volume' then profit_volume_eur
        when aa.agreed_attribution_rule = 'cost' then profit_cost_eur
    end as profit_agreed_rule_eur,
    aa.santaka_litres_served,
    aa.tickets_sold,
from
    c_event_profit_step_50 as aa
