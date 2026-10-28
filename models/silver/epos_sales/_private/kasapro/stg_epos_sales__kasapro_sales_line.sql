{#
    KasaPro leg conformed to epos_sales__sales_line.
    Source-specific rules: drop connector retry duplicates, link late happy-hour adjustments to their sale line,
    strip VAT from the VAT-inclusive prices.
#}
with
    {# Retry duplicates: keep the earliest export of each transaction line #}
    c_kasapro_lines_step_10 as (
        select
            ks.organiser_event_ref,
            ks.bar_name,
            ks.transaction_id,
            ks.line_no,
            ks.sold_at,
            ks.item_name,
            ks.quantity,
            ks.unit_price,
            ks.discount_amount,
            ks.line_amount,
            ks.payment_method,
            ks.line_type,
        from
            {{ ref('kasapro__sales_export') }} as ks
        qualify
            row_number() over (
                partition by
                    ks.transaction_id,
                    ks.line_no
                order by
                    ks.exported_at,
                    ks.export_batch_id
            ) = 1
    ),
    {# Promo adjustment line 9x discounts sale line x of the same transaction and inherits its item #}
    c_kasapro_lines_step_20 as (
        select
            aa.*,
            iff(aa.line_type = 'promo_adjustment', aa.line_no - 90, aa.line_no) as sale_line_no,
            coalesce(bb.item_name, aa.item_name) as sold_item_name,
        from
            c_kasapro_lines_step_10 as aa
        left join
            c_kasapro_lines_step_10 as bb
            on
                aa.line_type = 'promo_adjustment' and
                bb.line_type = 'sale' and
                bb.transaction_id = aa.transaction_id and
                bb.line_no = aa.line_no - 90
    )
select
    'kasapro' as epos_system_code,
    aa.organiser_event_ref,
    aa.transaction_id,
    aa.line_no,
    aa.sale_line_no,
    aa.line_type,
    aa.sold_at,
    try_to_number(split_part(aa.bar_name, ' ', 2)) as bar_no,
    aa.sold_item_name as epos_item_key,
    aa.quantity,
    aa.payment_method,
    aa.line_amount as line_amount_as_reported,
    {# KasaPro prices include VAT at the 21 % standard rate #}
    round(aa.unit_price * aa.quantity / 1.21, 4) as list_amount_net,
    round(aa.discount_amount / 1.21, 4) as discount_amount_net,
    round(aa.line_amount / 1.21, 4) as line_amount_net,
from
    c_kasapro_lines_step_20 as aa
