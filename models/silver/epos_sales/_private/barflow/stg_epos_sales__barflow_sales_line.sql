{#
    BarFlow leg conformed to epos_sales__sales_line.
    Source-specific rules: drop voided receipts, cents to euros, map Lithuanian tender codes.
    BarFlow amounts are already net of VAT; it has no late promo adjustments.
#}
select
    'barflow' as epos_system_code,
    bf.location_id as organiser_event_ref,
    bf.receipt_no as transaction_id,
    bf.position as line_no,
    bf.position as sale_line_no,
    'sale' as line_type,
    bf.created_at as sold_at,
    try_to_number(substr(bf.bar_code, 2)) as bar_no,
    bf.plu::varchar as epos_item_key,
    bf.qty as quantity,
    case
        when bf.tender = 'KORTELE' then 'card'
        when bf.tender = 'GRYNIEJI' then 'cash'
        when bf.tender = 'KVIETIMAS' then 'vip_voucher'
    end as payment_method,
    bf.line_net_cents / 100 as line_amount_as_reported,
    bf.unit_net_cents * bf.qty / 100 as list_amount_net,
    bf.discount_net_cents / 100 as discount_amount_net,
    bf.line_net_cents / 100 as line_amount_net,
from
    {{ ref('barflow__receipt_lines') }} as bf
where
    bf.status = 'OK'
