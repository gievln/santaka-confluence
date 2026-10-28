{# Grain: one row per event and Santaka menu item; organiser's statement next to Santaka's own figures. #}
select
    (
        case
            when sr.event_code is null then '-1'
            else {{ md5_composite_keys('sr.event_code') }}
        end
    )::varchar as event_xid,
    (
        case
            when sr.menu_item is null then '-1'
            else {{ md5_composite_keys('sr.menu_item') }}
        end
    )::varchar as menu_item_xid,
    sr.is_on_statement::boolean as is_on_statement,
    sr.reconciliation_status::varchar as reconciliation_status,
    sr.statement_quantity_sold::number(38, 0) as statement_quantity_sold,
    sr.model_quantity_sold::number(38, 0) as model_quantity_sold,
    sr.statement_attributed_sales_eur::number(14, 4) as statement_attributed_sales_eur,
    sr.model_attributed_sales_volume_eur::number(14, 4) as model_attributed_sales_volume_eur,
    sr.model_attributed_sales_cost_eur::number(14, 4) as model_attributed_sales_cost_eur,
    sr.statement_payable_eur::number(14, 4) as statement_payable_eur,
    sr.model_revenue_share_volume_eur::number(14, 4) as model_revenue_share_volume_eur,
    sr.model_revenue_share_cost_eur::number(14, 4) as model_revenue_share_cost_eur,
    sr.payable_data_gap_eur::number(14, 4) as payable_data_gap_eur,
    sr.payable_rule_gap_eur::number(14, 4) as payable_rule_gap_eur,
from
    {{ ref('settlement__reconciliation') }} as sr
