{{ config(materialized='semantic_view', static_analysis='off') }}
{# Semantic view on the raw exports, as a quick AI pilot would wire it. Same AI, same questions; only the data differs. #}
tables (
    sales as {{ ref('naive__sales_line') }}
        with synonyms = ('bar sales', 'santaka sales', 'pardavimai', 'baro pardavimai')
        comment = 'Bar sales from the organisers EPOS exports. EUR.',
    events as {{ ref('santaka_crm__events') }}
        primary key (event_code)
        with synonyms = ('events', 'concerts', 'festivals', 'renginiai', 'koncertai', 'festivaliai')
        comment = 'Concerts and festivals Santaka supplied in summer 2026.',
    costs as {{ ref('santaka_erp__event_costs') }}
        with synonyms = ('event costs', 'expenses', 'kaštai', 'išlaidos')
        comment = 'Santaka own costs per event.'
)

relationships (
    sales_to_events as sales(event_code) references events,
    costs_to_events as costs(event_code) references events
)

facts (
    private sales.santaka_amount as iff(is_santaka_item, amount_eur, 0),
    private sales.santaka_share_amount as iff(is_santaka_item, amount_eur * revenue_share_pct, 0)
)

dimensions (
    events.event_name as event_name
        with synonyms = ('event', 'renginys', 'renginio pavadinimas')
        comment = 'Event name',
    events.organiser_name as organiser_name
        with synonyms = ('organiser', 'organizatorius')
        comment = 'Event organiser company',
    sales.item_name as item_name
        with synonyms = ('item', 'drink', 'cocktail', 'kokteilis', 'gėrimas')
        comment = 'Item as printed on the receipt',
    sales.sales_date as sales_date
        with synonyms = ('date', 'data')
        comment = 'Date of sale'
)

metrics (
    sales.total_sales as sum(amount_eur)
        comment = 'All bar sales. EUR.',
    sales.santaka_sales as sum(santaka_amount)
        with synonyms = ('santaka sales', 'santakos pardavimai')
        comment = 'Sales of Santaka products and cocktails. EUR.',
    sales.santaka_revenue as sum(santaka_share_amount)
        with synonyms = ('revenue', 'pajamos')
        comment = 'Santaka revenue share. EUR.',
    sales.units_sold as sum(quantity)
        comment = 'Units sold.',
    costs.total_event_costs as sum(amount_eur)
        with synonyms = ('event costs', 'išlaidos')
        comment = 'Santaka own event costs. EUR.'
)

comment = 'Santaka (Kaunas drinks maker) at summer 2026 concerts and festivals, straight from the organisers sales exports.'

ai_sql_generation '
All money is EUR. Round money to 2 decimals.
Questions may be in Lithuanian: renginys = event, pelnas = profit, pelningiausi = most profitable, festivalis = festival, koncertas = concert, kokteilis = cocktail, pardavimai = sales, organizatorius = organiser.
Profit = santaka_revenue - total_event_costs.
'

ai_question_categorization '
Answer questions about Santaka sales, revenue, profit, costs and events for summer 2026.
'
