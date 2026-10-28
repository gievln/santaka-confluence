select
    pr.sku,
    pr.product_name,
    pr.category,
    pr.abv_pct,
    pr.pack,
    pr.pack_volume_ml,
    pr.list_price_eur_per_l,
    pr.production_cost_eur_per_l,
from
    {{ ref('santaka_erp__products') }} as pr
