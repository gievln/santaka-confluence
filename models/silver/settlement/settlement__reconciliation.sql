{#
    Organiser's statement vs Santaka's own figures, one row per event and Santaka menu item.
    Business rules:
      - data gap = Santaka's volume-rule share minus the organiser's payable: same rule, so any gap is a data problem;
      - rule gap = cost-rule share minus volume-rule share: the open commercial question;
      - a line matches when the data gap is within EUR 1 (rounding across thousands of lines);
      - a menu item Santaka sold but the organiser did not list is missing_from_statement.
#}
with
    {# Santaka's attributed sales and shares from the cleaned EPOS data #}
    c_model_sales_step_10 as (
        select
            ss.event_code,
            ss.menu_item,
            sum(ss.attributed_sales_volume_eur) as attributed_sales_volume_eur_sum,
            sum(ss.attributed_sales_cost_eur) as attributed_sales_cost_eur_sum,
            sum(ss.revenue_share_volume_eur) as revenue_share_volume_eur_sum,
            sum(ss.revenue_share_cost_eur) as revenue_share_cost_eur_sum,
        from
            {{ ref('epos_sales__santaka_sales_line') }} as ss
        group by
            ss.event_code,
            ss.menu_item
    ),
    {# Units sold per menu item, counted on sale lines before the per-SKU split so cocktails count once #}
    c_model_quantity_step_20 as (
        select
            sl.event_code,
            sl.menu_item,
            sum(sl.quantity) as quantity_sold_sum,
        from
            {{ ref('epos_sales__sales_line') }} as sl
        join
            {{ ref('product__menu_item') }} as mi
            on
                mi.menu_item = sl.menu_item
        where
            sl.line_type = 'sale' and
            mi.menu_item_type != 'third_party'
        group by
            sl.event_code,
            sl.menu_item
    ),
    {# Line up Santaka's figures with the statement; either side may be missing #}
    c_reconciliation_step_30 as (
        select
            coalesce(aa.event_code, st.event_code) as event_code,
            coalesce(aa.menu_item, st.menu_item) as menu_item,
            st.event_code is not null as is_on_statement,
            coalesce(st.quantity_sold, 0) as statement_quantity_sold,
            coalesce(bb.quantity_sold_sum, 0) as model_quantity_sold,
            coalesce(st.attributed_sales_net_eur, 0) as statement_attributed_sales_eur,
            coalesce(aa.attributed_sales_volume_eur_sum, 0) as model_attributed_sales_volume_eur,
            coalesce(aa.attributed_sales_cost_eur_sum, 0) as model_attributed_sales_cost_eur,
            coalesce(st.payable_eur, 0) as statement_payable_eur,
            coalesce(aa.revenue_share_volume_eur_sum, 0) as model_revenue_share_volume_eur,
            coalesce(aa.revenue_share_cost_eur_sum, 0) as model_revenue_share_cost_eur,
        from
            c_model_sales_step_10 as aa
        left join
            c_model_quantity_step_20 as bb
            on
                bb.event_code = aa.event_code and
                bb.menu_item = aa.menu_item
        full outer join
            {{ ref('settlement__statement_line') }} as st
            on
                st.event_code = aa.event_code and
                st.menu_item = aa.menu_item
    )
select
    aa.event_code,
    aa.menu_item,
    aa.is_on_statement,
    aa.statement_quantity_sold,
    aa.model_quantity_sold,
    aa.statement_attributed_sales_eur,
    aa.model_attributed_sales_volume_eur,
    aa.model_attributed_sales_cost_eur,
    aa.statement_payable_eur,
    aa.model_revenue_share_volume_eur,
    aa.model_revenue_share_cost_eur,
    aa.model_revenue_share_volume_eur - aa.statement_payable_eur as payable_data_gap_eur,
    aa.model_revenue_share_cost_eur - aa.model_revenue_share_volume_eur as payable_rule_gap_eur,
    case
        when not aa.is_on_statement then 'missing_from_statement'
        when abs(payable_data_gap_eur) <= 1 then 'matched'
        else 'mismatch'
    end as reconciliation_status,
from
    c_reconciliation_step_30 as aa
