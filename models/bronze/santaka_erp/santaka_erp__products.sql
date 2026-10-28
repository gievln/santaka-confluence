select
    pr.sku::varchar as sku,
    pr.product_name::varchar as product_name,
    pr.category::varchar as category,
    pr.abv_pct::number(4, 1) as abv_pct,
    pr.pack::varchar as pack,
    pr.pack_volume_ml::integer as pack_volume_ml,
    pr.list_price_eur_per_l::number(10, 2) as list_price_eur_per_l,
    pr.production_cost_eur_per_l::number(10, 2) as production_cost_eur_per_l,
from
    {{ ref('santaka_products') }} as pr
