{# Grain: one row per calendar day. Keyed on the date itself, like the facts' date columns. #}
select
    cd.calendar_date::date as calendar_date,
    cd.calendar_year::number(38, 0) as calendar_year,
    cd.month_no::number(38, 0) as month_no,
    cd.month_name::varchar as month_name,
    cd.iso_week_no::number(38, 0) as iso_week_no,
    cd.iso_day_of_week::number(38, 0) as iso_day_of_week,
    cd.day_name::varchar as day_name,
    cd.is_weekend::boolean as is_weekend,
    cd.season::varchar as season,
    cd.is_public_holiday::boolean as is_public_holiday,
    cd.public_holiday_name::varchar as public_holiday_name,
from
    {{ ref('calendar__date') }} as cd
