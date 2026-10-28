{# Bar manager's Excel sheet: cocktail name only on its first row, decimal commas. Blank names are filled forward in silver using sheet_row_no. #}
select
    br.nr::integer as sheet_row_no,
    nullif(trim(br.kokteilis::varchar), '') as cocktail_name,
    trim(br.ingredientas::varchar) as ingredient_name,
    try_to_number(br.kiekis_ml::varchar) as ingredient_ml,
    try_to_number(replace(br.kaina_eur_l::varchar, ',', '.'), 10, 2) as ingredient_cost_eur_per_l,
    nullif(trim(br.tiekejas::varchar), '') as supplier_name,
from
    {{ ref('bar_recipes') }} as br
