{# One row per day of 2026 with weekday, season and Lithuanian public holidays. #}
with
    {# One row per day; 365 = days in 2026 #}
    c_date_spine_step_10 as (
        select
            dateadd('day', row_number() over (order by seq4()) - 1, '2026-01-01'::date) as calendar_date,
        from
            table(generator(rowcount => 365))
    )
select
    aa.calendar_date,
    year(aa.calendar_date) as calendar_year,
    month(aa.calendar_date) as month_no,
    monthname(aa.calendar_date) as month_name,
    weekiso(aa.calendar_date) as iso_week_no,
    dayofweekiso(aa.calendar_date) as iso_day_of_week,
    dayname(aa.calendar_date) as day_name,
    dayofweekiso(aa.calendar_date) in (6, 7) as is_weekend,
    case
        when month(aa.calendar_date) in (12, 1, 2) then 'winter'
        when month(aa.calendar_date) in (3, 4, 5) then 'spring'
        when month(aa.calendar_date) in (6, 7, 8) then 'summer'
        else 'autumn'
    end as season,
    ph.holiday_date is not null as is_public_holiday,
    ph.holiday_name as public_holiday_name,
from
    c_date_spine_step_10 as aa
left join
    {{ ref('ref_lt_public_holidays') }} as ph
    on
        ph.holiday_date::date = aa.calendar_date
