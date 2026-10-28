{#
    One row per menu item and Santaka SKU it contains, with Santaka's share under both attribution rules.
    Standalone Santaka products are 100 % Santaka; cocktails are split by recipe volume or by ingredient cost.
    Ice and garnish have no volume or cost, so they do not dilute either split.
#}
with
    {# Recipe totals per cocktail, the denominators of both splits #}
    c_recipe_totals_step_10 as (
        select
            ri.recipe_cocktail_name,
            sum(ri.ingredient_ml) as recipe_ml_sum,
            sum(ri.ingredient_cost_eur) as recipe_cost_eur_sum,
        from
            {{ ref('recipe__ingredient') }} as ri
        group by
            ri.recipe_cocktail_name
    ),
    {# Santaka ingredients of each cocktail as a share of its volume and cost #}
    c_cocktail_allocations_step_20 as (
        select
            mi.menu_item,
            ri.santaka_sku,
            ri.ingredient_ml as santaka_ml_per_serve,
            ri.ingredient_ml / aa.recipe_ml_sum as volume_allocation_pct,
            ri.ingredient_cost_eur / aa.recipe_cost_eur_sum as cost_allocation_pct,
        from
            {{ ref('recipe__ingredient') }} as ri
        join
            c_recipe_totals_step_10 as aa
            on
                aa.recipe_cocktail_name = ri.recipe_cocktail_name
        join
            {{ ref('product__menu_item') }} as mi
            on
                mi.recipe_cocktail_name = ri.recipe_cocktail_name
        where
            ri.is_santaka_ingredient
    ),
    {# Standalone Santaka products belong to Santaka in full under either rule #}
    c_product_allocations_step_30 as (
        select
            mi.menu_item,
            mi.santaka_sku,
            mi.serve_ml as santaka_ml_per_serve,
            1 as volume_allocation_pct,
            1 as cost_allocation_pct,
        from
            {{ ref('product__menu_item') }} as mi
        where
            mi.menu_item_type = 'santaka_product'
    ),
    {# Cocktails and standalone products in one list #}
    c_allocations_step_40 as (
        select
            aa.menu_item,
            aa.santaka_sku,
            aa.santaka_ml_per_serve,
            aa.volume_allocation_pct,
            aa.cost_allocation_pct,
        from
            c_cocktail_allocations_step_20 as aa

        union all

        select
            bb.menu_item,
            bb.santaka_sku,
            bb.santaka_ml_per_serve,
            bb.volume_allocation_pct,
            bb.cost_allocation_pct,
        from
            c_product_allocations_step_30 as bb
    )
select
    aa.menu_item,
    aa.santaka_sku,
    aa.santaka_ml_per_serve::number(10, 2) as santaka_ml_per_serve,
    aa.volume_allocation_pct::number(10, 6) as volume_allocation_pct,
    aa.cost_allocation_pct::number(10, 6) as cost_allocation_pct,
from
    c_allocations_step_40 as aa
