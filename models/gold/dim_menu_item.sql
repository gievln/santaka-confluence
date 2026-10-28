{# Grain: one row per bar menu item, plus the '-1' unknown member. #}
select
    {{ md5_composite_keys('mi.menu_item') }}::varchar as menu_item_xid,
    mi.menu_item::varchar as menu_item,
    mi.menu_item_type::varchar as menu_item_type,
    mi.serve_ml::number(38, 0) as serve_ml,
from
    {{ ref('product__menu_item') }} as mi

union all

select
    '-1'::varchar as menu_item_xid,
    'Unknown menu item'::varchar as menu_item,
    'Unknown'::varchar as menu_item_type,
    null::number(38, 0) as serve_ml
