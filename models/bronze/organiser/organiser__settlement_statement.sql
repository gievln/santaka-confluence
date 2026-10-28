{# Organiser's settlement statement (Excel, Lithuanian headers): their own calculation of Santaka's share per event and menu item. #}
select
    ss.renginys::varchar as organiser_event_ref,
    ss.israsymo_data::date as issued_on,
    trim(ss.pozicija::varchar) as item_description,
    ss.parduota_vnt::integer as quantity_sold,
    ss.pardavimai_be_pvm::number(14, 2) as attributed_sales_net_eur,
    ss.dalis_proc::number(5, 2) as revenue_share_pct_points,
    ss.moketina_suma::number(14, 2) as payable_eur,
from
    {{ ref('organiser_settlements') }} as ss
