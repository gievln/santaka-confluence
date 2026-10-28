{# KasaPro export (Garso Bangos), one row per exported line. Retries and late promo adjustments included. #}
select
    ks.export_batch_id::varchar as export_batch_id,
    ks.exported_at::timestamp_ntz as exported_at,
    ks.organiser_event_ref::varchar as organiser_event_ref,
    ks.bar_name::varchar as bar_name,
    ks.till_id::varchar as till_id,
    ks.transaction_id::varchar as transaction_id,
    ks.line_no::integer as line_no,
    ks.sold_at::timestamp_ntz as sold_at,
    ks.item_name::varchar as item_name,
    ks.quantity::integer as quantity,
    ks.unit_price::number(10, 2) as unit_price,
    ks.discount_amount::number(10, 2) as discount_amount,
    ks.line_amount::number(10, 2) as line_amount,
    ks.payment_method::varchar as payment_method,
    ks.line_type::varchar as line_type,
from
    {{ ref('kasapro_sales_export') }} as ks
