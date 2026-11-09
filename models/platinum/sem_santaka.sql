{{ config(materialized='semantic_view', static_analysis='off') }}
{# Semantic view on the cleaned gold layer: what Cortex Analyst answers from once the data is fixed. #}
tables (
    sales as {{ ref('fct_santaka_sales') }}
        primary key (epos_system_code, transaction_id, line_no, product_xid)
        with synonyms = ('bar sales', 'santaka sales', 'pardavimai', 'baro pardavimai')
        comment = 'Santaka share of bar sales. One row per EPOS line and Santaka product. EUR, net of VAT.',
    profit as {{ ref('fct_event_profit') }}
        primary key (event_xid)
        with synonyms = ('event profit', 'profitability', 'pelnas', 'pelningumas')
        comment = 'Santaka profit per event under both attribution rules.',
    tickets as {{ ref('fct_ticket_sales') }}
        primary key (event_xid, event_date, ticket_type)
        with synonyms = ('attendance', 'tickets', 'bilietai', 'lankytojai')
        comment = 'Tickets sold per event, day and ticket type.',
    costs as {{ ref('fct_event_costs') }}
        primary key (event_xid, cost_type)
        with synonyms = ('event costs', 'expenses', 'kaštai', 'išlaidos')
        comment = 'Santaka own costs per event: logistics, staff, branding, listing fee.',
    reconciliation as {{ ref('fct_settlement_reconciliation') }}
        primary key (event_xid, menu_item_xid)
        with synonyms = ('settlement', 'statement', 'organiser statement', 'atsiskaitymas', 'suderinimas')
        comment = 'Organiser settlement statement next to Santaka own figures, per event and menu item.',
    event as {{ ref('dim_event') }}
        primary key (event_xid)
        with synonyms = ('events', 'concerts', 'festivals', 'renginiai', 'koncertai', 'festivaliai')
        comment = 'Concerts and festivals Santaka supplied in summer 2026.',
    venue as {{ ref('dim_venue') }}
        primary key (venue_xid)
        with synonyms = ('venues', 'locations', 'vietos')
        comment = 'Event venues in Kaunas.',
    product as {{ ref('dim_product') }}
        primary key (product_xid)
        with synonyms = ('santaka products', 'drinks', 'produktai', 'gėrimai')
        comment = 'Santaka own products (bitter, mead, kvass, lemonade, cider, tonic).',
    menu_item as {{ ref('dim_menu_item') }}
        primary key (menu_item_xid)
        with synonyms = ('menu items', 'cocktails', 'meniu', 'kokteiliai')
        comment = 'What the bar sold: Santaka products, cocktails containing Santaka products, third-party items.',
    calendar as {{ ref('dim_date') }}
        primary key (calendar_date)
        with synonyms = ('dates', 'calendar', 'datos')
        comment = 'Calendar with weekends, seasons and Lithuanian public holidays.'
)

relationships (
    sales_to_calendar as sales(sales_date) references calendar(calendar_date),
    sales_to_event as sales(event_xid) references event,
    sales_to_venue as sales(venue_xid) references venue,
    sales_to_product as sales(product_xid) references product,
    sales_to_menu_item as sales(menu_item_xid) references menu_item,
    profit_to_event as profit(event_xid) references event,
    tickets_to_calendar as tickets(event_date) references calendar(calendar_date),
    tickets_to_event as tickets(event_xid) references event,
    costs_to_event as costs(event_xid) references event,
    reconciliation_to_event as reconciliation(event_xid) references event,
    reconciliation_to_menu_item as reconciliation(menu_item_xid) references menu_item
)

facts (
    private sales.serve_units as iff(line_type = 'sale', quantity, 0),
    private sales.voucher_units as iff(is_vip_voucher, quantity, 0),
    private reconciliation.is_missing_line as iff(reconciliation_status = 'missing_from_statement', 1, 0)
)

dimensions (
    event.event_name as event_name
        with synonyms = ('event', 'renginys', 'renginio pavadinimas')
        comment = 'Event name',
    event.event_code as event_code
        comment = 'Short event code, e.g. NG26',
    event.organiser_name as organiser_name
        with synonyms = ('organiser', 'organizatorius')
        comment = 'Event organiser company',
    event.is_festival as is_festival
        with synonyms = ('festival', 'festivalis')
        comment = 'True for multi-day festivals, false for one-day concerts',
    event.indoor_outdoor as indoor_outdoor
        with synonyms = ('indoor or outdoor', 'lauke ar viduje')
        comment = 'indoor or outdoor',
    event.event_start_date as start_date
        comment = 'First day of the event',
    event.event_days as event_days
        comment = 'Number of event days',
    event.capacity_per_day as capacity_per_day
        comment = 'Venue capacity per day',
    event.revenue_share_pct as revenue_share_pct
        with synonyms = ('revenue share', 'pajamų dalis')
        comment = 'Contracted share of Santaka attributed net sales (0.35 = 35 %)',
    event.agreed_attribution_rule as agreed_attribution_rule
        with synonyms = ('agreed rule', 'contract rule', 'sutarta taisyklė')
        comment = 'Cocktail split rule written into the contract: volume or cost. Null means no rule has been agreed.',
    venue.venue_name as venue_name
        with synonyms = ('venue', 'vieta')
        comment = 'Venue name',
    venue.venue_type as venue_type
        comment = 'park, arena, castle courtyard, sports hall, monastery grounds',
    product.product_name as product_name
        with synonyms = ('product', 'produktas')
        comment = 'Santaka product name',
    product.product_category as category
        comment = 'aperitif, mead, kvass, lemonade, cider, tonic',
    menu_item.menu_item_name as menu_item
        with synonyms = ('menu item', 'drink', 'cocktail', 'kokteilis', 'gėrimas')
        comment = 'Menu item as sold at the bar',
    menu_item.menu_item_type as menu_item_type
        comment = 'santaka_product, santaka_cocktail or third_party',
    calendar.calendar_date as calendar_date
        with synonyms = ('date', 'day', 'data', 'diena')
        comment = 'Calendar date',
    calendar.day_name as day_name
        comment = 'Day of week',
    calendar.month_name as month_name
        with synonyms = ('month', 'mėnuo')
        comment = 'Month',
    calendar.is_weekend as is_weekend
        comment = 'Saturday or Sunday',
    calendar.is_public_holiday as is_public_holiday
        comment = 'Lithuanian public holiday',
    calendar.public_holiday_name as public_holiday_name
        comment = 'Lithuanian public holiday name',
    sales.epos_system as epos_system_code
        comment = 'Source EPOS system: kasapro (Garso Bangos) or barflow (Arena Events)',
    sales.payment_method as payment_method
        comment = 'card, cash or vip_voucher',
    sales.line_type as line_type
        comment = 'sale or promo_adjustment (late happy-hour discount)',
    tickets.ticket_type as ticket_type
        comment = 'general or vip',
    costs.cost_type as cost_type
        comment = 'logistics, staff, branding or listing_fee',
    reconciliation.reconciliation_status as reconciliation_status
        comment = 'matched, mismatch or missing_from_statement'
)

metrics (
    sales.total_attributed_sales_volume as sum(attributed_sales_volume_eur)
        with synonyms = ('santaka sales by volume', 'attributed sales organiser rule')
        comment = 'Net sales attributed to Santaka, cocktails split by recipe volume (organiser preferred rule). EUR.',
    sales.total_attributed_sales_cost as sum(attributed_sales_cost_eur)
        with synonyms = ('santaka sales by cost', 'attributed sales santaka rule')
        comment = 'Net sales attributed to Santaka, cocktails split by ingredient cost (Santaka preferred rule). EUR.',
    sales.total_attributed_sales_as_reported as sum(attributed_sales_as_reported_cost_eur)
        comment = 'Attributed sales (cost rule) using amounts as exported, without the VAT fix. Only for before/after comparisons.',
    sales.total_revenue_share_volume as sum(revenue_share_volume_eur)
        with synonyms = ('revenue by volume', 'pajamos pagal tūrį')
        comment = 'Santaka revenue share, volume rule. EUR.',
    sales.total_revenue_share_cost as sum(revenue_share_cost_eur)
        with synonyms = ('revenue by cost', 'pajamos pagal savikainą')
        comment = 'Santaka revenue share, ingredient cost rule. EUR.',
    sales.total_cost_of_goods as sum(cost_of_goods_eur)
        with synonyms = ('cogs', 'savikaina')
        comment = 'Santaka production cost of the litres poured. EUR.',
    sales.total_litres_served as sum(santaka_ml_served) / 1000
        with synonyms = ('litres', 'volume poured', 'litrai')
        comment = 'Litres of Santaka product poured.',
    sales.serves_sold as sum(serve_units)
        with synonyms = ('units sold', 'drinks sold', 'parduota vienetų')
        comment = 'Menu item units sold (sale lines only).',
    sales.vip_voucher_serves as sum(voucher_units)
        comment = 'Drinks redeemed with VIP vouchers (organiser took 0 EUR).',
    profit.total_profit_volume as sum(profit_volume_eur)
        with synonyms = ('profit by volume', 'pelnas pagal tūrį')
        comment = 'Revenue share minus cost of goods minus event costs, volume rule. EUR.',
    profit.total_profit_cost as sum(profit_cost_eur)
        with synonyms = ('profit by cost', 'pelnas pagal savikainą')
        comment = 'Revenue share minus cost of goods minus event costs, ingredient cost rule. EUR.',
    profit.total_revenue_share_received as sum(revenue_share_received_eur)
        with synonyms = ('paid by organiser', 'received', 'gauta')
        comment = 'Revenue share the organiser settlement statement actually pays (organiser applies the volume rule). EUR.',
    profit.total_profit_received as sum(profit_received_eur)
        with synonyms = ('actual profit', 'realised profit', 'faktinis pelnas')
        comment = 'Profit on what the organiser actually pays: received share minus cost of goods minus event costs. EUR.',
    profit.total_profit_agreed_rule as sum(profit_agreed_rule_eur)
        comment = 'Profit under the rule agreed in the contract. Null while no rule is agreed. EUR.',
    profit.profit_per_attendee_volume as sum(profit_volume_eur) / nullif(sum(tickets_sold), 0)
        comment = 'Profit per ticket sold, volume rule. EUR.',
    profit.profit_per_attendee_cost as sum(profit_cost_eur) / nullif(sum(tickets_sold), 0)
        comment = 'Profit per ticket sold, ingredient cost rule. EUR.',
    tickets.total_tickets_sold as sum(tickets_sold)
        with synonyms = ('attendance', 'lankytojų skaičius')
        comment = 'Tickets sold.',
    costs.total_event_costs as sum(amount_eur)
        with synonyms = ('event costs', 'išlaidos')
        comment = 'Santaka own event costs. EUR.',
    reconciliation.total_statement_payable as sum(statement_payable_eur)
        with synonyms = ('organiser says we are owed', 'statement amount', 'mokėtina suma')
        comment = 'What the organiser statement says it owes Santaka. EUR.',
    reconciliation.total_model_payable_volume as sum(model_revenue_share_volume_eur)
        comment = 'What Santaka own data says it is owed under the same volume rule. EUR.',
    reconciliation.total_payable_data_gap as sum(payable_data_gap_eur)
        with synonyms = ('discrepancy', 'underpayment', 'neatitikimas')
        comment = 'Santaka figure minus organiser statement under the same rule; non-zero means a data problem. EUR.',
    reconciliation.total_payable_rule_gap as sum(payable_rule_gap_eur)
        comment = 'Extra Santaka would receive if cocktails were split by ingredient cost. EUR.',
    reconciliation.missing_statement_lines as sum(is_missing_line)
        comment = 'Menu items Santaka sold that the organiser left off the statement.'
)

comment = 'Santaka (Kaunas drinks maker) at summer 2026 concerts and festivals: sales, profit, attendance and organiser settlements, built on cleaned and reconciled data.'

ai_sql_generation '
GENERAL RULES:
All money is EUR, net of VAT. Round money to 2 decimals.
Questions may be in Lithuanian: renginys = event, pelnas = profit, pelningiausi = most profitable, festivalis = festival, koncertas = concert, kokteilis = cocktail, pardavimai = sales, organizatorius = organiser.

ATTRIBUTION RULES:
Santaka earns a contracted revenue share of the organiser bar sales of Santaka products.
Cocktails mix Santaka and third-party ingredients and the contract does not say how to split them.
There are two rules: by recipe volume (columns and metrics ending in _volume, the organiser preferred rule) and by ingredient cost (ending in _cost, Santaka preferred rule).
When asked about sales, revenue or profit without naming a rule, always return both side by side and label them "by volume (organiser rule)" and "by cost (Santaka rule)".

PROFIT:
Profit = revenue share - cost of goods - event costs, always profit for Santaka.
Check event.agreed_attribution_rule first. If it is set, answer with profit.total_profit_agreed_rule.
If it is null (no rule agreed), return three columns: total_profit_received (what the organiser actually pays, volume rule applied by the organiser),
total_profit_volume and total_profit_cost, and state that the contract does not specify how cocktails are split.
For "most profitable" questions rank events by total_profit_received; use profit_per_attendee metrics only when asked per person or per attendee.

SETTLEMENT:
For questions about what the organiser owes, the settlement statement, or discrepancies, use the reconciliation metrics.
total_payable_data_gap isolates data problems (same rule on both sides); total_payable_rule_gap is the split rule dispute.

BEFORE / AFTER:
Use total_attributed_sales_as_reported only when asked about raw, uncleaned or VAT-inclusive figures.
'

ai_question_categorization '
Answer questions about Santaka sales, profit, attendance, costs, products, cocktails, events and organiser settlements for summer 2026.
'

ai_verified_queries (
    most_profitable_events as (
        question 'Which events were most profitable for Santaka?'
        verified_at 1793145600
        onboarding_question true
        verified_by 'Giedrius Valancius'
        sql 'select
                 event_name,
                 iff(is_festival, ''festival'', ''concert'') as event_type,
                 coalesce(agreed_attribution_rule, ''not agreed'') as agreed_rule,
                 round(total_profit_received, 2) as profit_received_eur,
                 round(total_profit_volume, 2) as profit_by_volume_organiser_rule_eur,
                 round(total_profit_cost, 2) as profit_by_cost_santaka_rule_eur
             from semantic_view(
                 {{ this }}
                 dimensions event.event_name, event.is_festival, event.agreed_attribution_rule
                 metrics profit.total_profit_received, profit.total_profit_volume, profit.total_profit_cost
             )
             order by profit_received_eur desc'
    ),
    settlement_discrepancies as (
        question 'Does the organiser settlement statement match our figures?'
        verified_at 1793145600
        onboarding_question true
        verified_by 'Giedrius Valancius'
        sql 'select
                 event_name,
                 menu_item_name,
                 reconciliation_status,
                 round(total_statement_payable, 2) as organiser_statement_eur,
                 round(total_model_payable_volume, 2) as santaka_figure_same_rule_eur,
                 round(total_payable_data_gap, 2) as underpaid_eur
             from semantic_view(
                 {{ this }}
                 dimensions event.event_name, menu_item.menu_item_name, reconciliation.reconciliation_status
                 metrics reconciliation.total_statement_payable, reconciliation.total_model_payable_volume, reconciliation.total_payable_data_gap
             )
             where reconciliation_status != ''matched''
             order by underpaid_eur desc'
    ),
    cocktail_split_rule_effect as (
        question 'How much does the cocktail split rule change Santaka sales?'
        verified_at 1793145600
        onboarding_question true
        verified_by 'Giedrius Valancius'
        sql 'select
                 menu_item_name,
                 round(total_attributed_sales_volume, 2) as santaka_sales_by_volume_eur,
                 round(total_attributed_sales_cost, 2) as santaka_sales_by_cost_eur,
                 round(total_attributed_sales_cost - total_attributed_sales_volume, 2) as split_rule_difference_eur
             from semantic_view(
                 {{ this }}
                 dimensions menu_item.menu_item_name, menu_item.menu_item_type
                 metrics sales.total_attributed_sales_volume, sales.total_attributed_sales_cost
             )
             where menu_item_type = ''santaka_cocktail''
             order by split_rule_difference_eur desc'
    )
)
