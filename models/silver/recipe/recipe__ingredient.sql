{# One row per cocktail ingredient. Ice/garnish rows kept with null volume and cost. #}
with
    {# Cocktail name is only on the first row of each block in the sheet: fill it down #}
    c_recipe_sheet_step_10 as (
        select
            br.sheet_row_no,
            last_value(br.cocktail_name) ignore nulls over (
                order by
                    br.sheet_row_no
                rows between unbounded preceding and current row
            ) as recipe_cocktail_name,
            br.ingredient_name,
            br.ingredient_ml,
            br.ingredient_cost_eur_per_l,
            br.supplier_name,
        from
            {{ ref('bar_sheet__recipes') }} as br
    )
select
    aa.sheet_row_no,
    aa.recipe_cocktail_name,
    aa.ingredient_name,
    ri.santaka_sku,
    ri.santaka_sku is not null as is_santaka_ingredient,
    aa.ingredient_ml,
    aa.ingredient_cost_eur_per_l,
    round(aa.ingredient_ml * aa.ingredient_cost_eur_per_l / 1000, 4) as ingredient_cost_eur,
    aa.supplier_name,
from
    c_recipe_sheet_step_10 as aa
left join
    {{ ref('ref_recipe_ingredients') }} as ri
    on
        ri.ingredient_name = aa.ingredient_name
