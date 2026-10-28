{# Bar menu items across all EPOS systems; santaka_sku only for standalone Santaka products. #}
select
    mi.menu_item::varchar as menu_item,
    mi.menu_item_type::varchar as menu_item_type,
    mi.santaka_sku::varchar as santaka_sku,
    mi.serve_ml::integer as serve_ml,
    mi.recipe_cocktail_name::varchar as recipe_cocktail_name,
from
    {{ ref('ref_menu_items') }} as mi
