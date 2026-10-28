{# Grain: one row per menu item and Santaka product it contains, with both attribution weights. #}
select
    {{ md5_composite_keys('ma.menu_item') }}::varchar as menu_item_xid,
    {{ md5_composite_keys('ma.santaka_sku') }}::varchar as product_xid,
    ma.santaka_ml_per_serve::number(10, 2) as santaka_ml_per_serve,
    ma.volume_allocation_pct::number(10, 6) as volume_allocation_pct,
    ma.cost_allocation_pct::number(10, 6) as cost_allocation_pct,
from
    {{ ref('recipe__menu_item_allocation') }} as ma
