{# Grain: one row per Santaka product, plus the '-1' unknown member. #}
select
    {{ md5_composite_keys('pr.sku') }}::varchar as product_xid,
    pr.sku::varchar as sku,
    pr.product_name::varchar as product_name,
    pr.category::varchar as category,
    pr.abv_pct::number(4, 1) as abv_pct,
    pr.pack::varchar as pack,
    pr.pack_volume_ml::number(38, 0) as pack_volume_ml,
    pr.list_price_eur_per_l::number(10, 2) as list_price_eur_per_l,
    pr.production_cost_eur_per_l::number(10, 2) as production_cost_eur_per_l,
from
    {{ ref('product__product') }} as pr

union all

select
    '-1'::varchar as product_xid,
    '-1'::varchar as sku,
    'Unknown product'::varchar as product_name,
    'Unknown'::varchar as category,
    null::number(4, 1) as abv_pct,
    null::varchar as pack,
    null::number(38, 0) as pack_volume_ml,
    null::number(10, 2) as list_price_eur_per_l,
    null::number(10, 2) as production_cost_eur_per_l
