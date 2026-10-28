{#
    Deliberately naive: what a quick AI pilot wired straight onto the raw EPOS exports looks like.
    Kept mistakes, on purpose: retry duplicates and voided receipts counted, KasaPro amounts incl. VAT next to
    BarFlow amounts excl. VAT, cocktails credited 100 % to Santaka, late happy-hour discounts ignored.
#}
with
    {# KasaPro export as delivered, retries and all #}
    c_kasapro_raw_step_10 as (
        select
            'kasapro' as epos_system_code,
            ks.organiser_event_ref,
            ks.transaction_id,
            ks.sold_at,
            ks.item_name,
            ks.item_name as epos_item_key,
            ks.quantity,
            ks.line_amount as amount_eur,
        from
            {{ ref('kasapro__sales_export') }} as ks
    ),
    {# BarFlow export as delivered, voided receipts included #}
    c_barflow_raw_step_20 as (
        select
            'barflow' as epos_system_code,
            bf.location_id as organiser_event_ref,
            bf.receipt_no as transaction_id,
            bf.created_at as sold_at,
            bf.item_label as item_name,
            bf.plu::varchar as epos_item_key,
            bf.qty as quantity,
            bf.line_net_cents / 100 as amount_eur,
        from
            {{ ref('barflow__receipt_lines') }} as bf
    ),
    {# Both exports stacked as-is, no conforming #}
    c_raw_lines_step_30 as (
        select
            aa.epos_system_code,
            aa.organiser_event_ref,
            aa.transaction_id,
            aa.sold_at,
            aa.item_name,
            aa.epos_item_key,
            aa.quantity,
            aa.amount_eur,
        from
            c_kasapro_raw_step_10 as aa

        union all

        select
            bb.epos_system_code,
            bb.organiser_event_ref,
            bb.transaction_id,
            bb.sold_at,
            bb.item_name,
            bb.epos_item_key,
            bb.quantity,
            bb.amount_eur,
        from
            c_barflow_raw_step_20 as bb
    )
select
    aa.epos_system_code,
    ev.event_code,
    ev.event_name,
    ev.organiser_name,
    aa.transaction_id,
    aa.sold_at,
    aa.sold_at::date as sales_date,
    aa.item_name,
    aa.quantity,
    aa.amount_eur::number(14, 2) as amount_eur,
    {# Naive rule: anything on the Santaka menu counts in full, cocktails included #}
    coalesce(mi.menu_item_type in ('santaka_product', 'santaka_cocktail'), false) as is_santaka_item,
    co.revenue_share_pct,
from
    c_raw_lines_step_30 as aa
left join
    {{ ref('santaka_crm__events') }} as ev
    on
        ev.organiser_event_ref = aa.organiser_event_ref
left join
    {{ ref('santaka_crm__contracts') }} as co
    on
        co.event_code = ev.event_code
left join
    {{ ref('ref_epos_item_map') }} as im
    on
        im.epos_system_code = aa.epos_system_code and
        im.epos_item_key::varchar = aa.epos_item_key
left join
    {{ ref('ref_menu_items') }} as mi
    on
        mi.menu_item = im.menu_item
