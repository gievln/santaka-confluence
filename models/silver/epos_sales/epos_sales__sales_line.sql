{#
    All EPOS lines from every system, one row per epos_system_code + transaction_id + line_no.
    Legs arrive deduplicated, net of VAT and in conformed codes; here they get Santaka's event and menu item.
#}
with
    {# Stack the conformed legs; casts pin both legs to one set of types #}
    c_sales_lines_step_10 as (
        select
            kl.epos_system_code::varchar as epos_system_code,
            kl.organiser_event_ref::varchar as organiser_event_ref,
            kl.transaction_id::varchar as transaction_id,
            kl.line_no::integer as line_no,
            kl.sale_line_no::integer as sale_line_no,
            kl.line_type::varchar as line_type,
            kl.sold_at::timestamp_ntz as sold_at,
            kl.bar_no::integer as bar_no,
            kl.epos_item_key::varchar as epos_item_key,
            kl.quantity::integer as quantity,
            kl.payment_method::varchar as payment_method,
            kl.line_amount_as_reported::number(12, 2) as line_amount_as_reported,
            kl.list_amount_net::number(12, 4) as list_amount_net,
            kl.discount_amount_net::number(12, 4) as discount_amount_net,
            kl.line_amount_net::number(12, 4) as line_amount_net,
        from
            {{ ref('stg_epos_sales__kasapro_sales_line') }} as kl

        union all

        select
            bl.epos_system_code::varchar as epos_system_code,
            bl.organiser_event_ref::varchar as organiser_event_ref,
            bl.transaction_id::varchar as transaction_id,
            bl.line_no::integer as line_no,
            bl.sale_line_no::integer as sale_line_no,
            bl.line_type::varchar as line_type,
            bl.sold_at::timestamp_ntz as sold_at,
            bl.bar_no::integer as bar_no,
            bl.epos_item_key::varchar as epos_item_key,
            bl.quantity::integer as quantity,
            bl.payment_method::varchar as payment_method,
            bl.line_amount_as_reported::number(12, 2) as line_amount_as_reported,
            bl.list_amount_net::number(12, 4) as list_amount_net,
            bl.discount_amount_net::number(12, 4) as discount_amount_net,
            bl.line_amount_net::number(12, 4) as line_amount_net,
        from
            {{ ref('stg_epos_sales__barflow_sales_line') }} as bl
    )
select
    aa.epos_system_code,
    aa.transaction_id,
    aa.line_no,
    aa.sale_line_no,
    aa.line_type,
    ev.event_code,
    aa.organiser_event_ref,
    aa.sold_at,
    aa.sold_at::date as sales_date,
    aa.bar_no,
    aa.epos_item_key,
    im.menu_item,
    aa.quantity,
    aa.payment_method,
    aa.line_amount_as_reported,
    aa.list_amount_net,
    aa.discount_amount_net,
    aa.line_amount_net,
from
    c_sales_lines_step_10 as aa
left join
    {{ ref('santaka_crm__events') }} as ev
    on
        ev.organiser_event_ref = aa.organiser_event_ref
left join
    {{ ref('ref_epos_item_map') }} as im
    on
        im.epos_system_code = aa.epos_system_code and
        im.epos_item_key::varchar = aa.epos_item_key
