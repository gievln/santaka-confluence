{# BarFlow export (Arena Events), one row per receipt line. Voided receipts included; amounts in cents excl. VAT. #}
select
    bf.receipt_no::varchar as receipt_no,
    bf.position::integer as position,
    bf.location_id::varchar as location_id,
    bf.bar_code::varchar as bar_code,
    try_to_timestamp_ntz(bf.created_local::varchar, 'DD.MM.YYYY HH24:MI:SS') as created_at,
    bf.plu::integer as plu,
    bf.item_label::varchar as item_label,
    bf.qty::integer as qty,
    bf.unit_net_cents::integer as unit_net_cents,
    bf.discount_net_cents::integer as discount_net_cents,
    bf.line_net_cents::integer as line_net_cents,
    bf.vat_cents::integer as vat_cents,
    bf.tender::varchar as tender,
    bf.status::varchar as status,
from
    {{ ref('barflow_receipt_lines') }} as bf
