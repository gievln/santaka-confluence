"""Generate mocked Santaka raw sources into seeds/raw/. Deterministic: same seed, same CSVs.

Two EPOS systems with different export shapes:
  - KasaPro (Garso Bangos): free-text item labels, VAT-inclusive prices, connector retry duplicates,
    happy-hour discounts arriving days later as adjustment lines.
  - BarFlow (Arena Events): PLU codes, amounts in cents excl. VAT with VAT in its own column,
    dd.mm.yyyy timestamps, voided receipts left in the export.
"""

import csv
import random
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

SEED = 2026
VAT = 0.21
OUT = Path(__file__).resolve().parent.parent / "seeds" / "raw"
rng = random.Random(SEED)

ORGANISERS = {
    "Garso Bangos UAB": {"prefix": "GB", "epos": "kasapro"},
    "Arena Events LT": {"prefix": "AE", "epos": "barflow"},
}

EVENTS = [
    # code, name, organiser, venue, start, days, indoor_outdoor, capacity/day, fill rate, bars
    ("NG26", "Nemuno Garsai", "Garso Bangos UAB", "Santakos parkas", date(2026, 7, 10), 3, "outdoor", 4500, 0.92, 4),
    ("KVN26", "Kauno Vasaros Naktys", "Garso Bangos UAB", "Ąžuolynas", date(2026, 8, 7), 2, "outdoor", 3950, 0.88, 3),
    ("KMV26", "Kino muzikos vakaras", "Garso Bangos UAB", "Kauno pilies kiemas", date(2026, 6, 27), 1, "outdoor", 2500, 0.97, 2),
    ("LO26", "Lina ir orkestras", "Arena Events LT", "Žalgirio arena", date(2026, 6, 13), 1, "indoor", 9000, 0.81, 3),
    ("DN26", "Džiazo naktis", "Arena Events LT", "Kauno sporto halė", date(2026, 7, 25), 1, "indoor", 3500, 0.74, 2),
    ("RP26", "Rokas Pažaislyje", "Arena Events LT", "Pažaislio vienuolynas", date(2026, 8, 22), 1, "outdoor", 3000, 0.95, 2),
]

# Santaka's own catalogue; list price is what bars pay per litre, production cost is Santaka's.
PRODUCTS = [
    ("SNT-BIT-07", "Santaka Bitter", "aperitif", 18.0, "bottle 0.7 l", 700, 24.00, 7.80),
    ("SNT-MID-05", "Santaka Midus", "mead", 14.0, "bottle 0.5 l", 500, 30.00, 9.50),
    ("SNT-GIR-30", "Santaka Gira", "kvass", 0.5, "keg 30 l", 30000, 2.40, 0.70),
    ("SNT-RAB-33", "Santaka Rabarbarų limonadas", "lemonade", 0.0, "can 0.33 l", 330, 3.60, 1.10),
    ("SNT-SID-30", "Santaka Sidras", "cider", 4.5, "keg 30 l", 30000, 4.20, 1.40),
    ("SNT-TON-20", "Santaka Tonikas", "tonic", 0.0, "bag-in-box 20 l", 20000, 3.00, 0.60),
]

# Bar menu, gross prices incl. VAT. KasaPro labels are free text typed per till; BarFlow uses PLU codes.
MENU = {
    "Santaka Spritz": {"price": 11.00, "weight": 17, "plu": 1001, "names": ["Santaka Spritz", "SPRITZ", "Spritz Santaka 0.2", "Spritzas"]},
    "Midaus Mule": {"price": 10.00, "weight": 7, "plu": 1002, "names": ["Midaus Mule", "MULE midus", "Mule (Santaka)"]},
    "Santaka G&T": {"price": 12.00, "weight": 6, "plu": 1003, "names": ["Santaka G&T", "Gin Tonic", "G&T"]},
    "Santaka Gira 0.5": {"price": 5.00, "weight": 6, "plu": 2001, "names": ["Gira 0.5", "Santaka gira", "GIRA"]},
    "Rabarbarų limonadas": {"price": 4.50, "weight": 7, "plu": 2002, "names": ["Rabarbarų limonadas", "Limonadas rabarb.", "Rhubarb lemonade"]},
    "Santaka Sidras 0.5": {"price": 7.00, "weight": 5, "plu": 2003, "names": ["Sidras 0.5", "Santaka Sidras", "CIDER"]},
    "Santaka Midus 50 ml": {"price": 6.00, "weight": 3, "plu": 2004, "names": ["Midus 50ml", "Midaus šotas"]},
    "Alus Kalnapilis 0.5": {"price": 6.00, "weight": 36, "plu": 3001, "names": ["Alus 0.5", "Kalnapilis 0.5", "BEER"]},
    "Vanduo 0.5": {"price": 3.00, "weight": 10, "plu": 3002, "names": ["Vanduo", "Water 0.5"]},
    "Dešrainis": {"price": 7.00, "weight": 7, "plu": 4001, "names": ["Dešrainis", "Hot dog"]},
}

# Bar manager's recipe sheet, as an Excel export: cocktail name only on the first row, decimal commas.
RECIPES = [
    ("Santaka Spritz", [("Santaka bitter", "75", "24,00", "Santaka"), ("Prosecco", "60", "9,00", "Vynoteka"),
                        ("Soda", "15", "4,00", "Vynoteka"), ("Ledas", "", "", "")]),
    ("Midaus Mule", [("Santaka midus", "50", "30,00", "Santaka"), ("Ginger beer", "100", "4,00", "Vynoteka"),
                     ("Laimas (sultys)", "10", "10,00", "Rimi"), ("Ledas", "", "", "")]),
    ("G&T", [("Džinas Gordon's", "40", "40,00", "Vynoteka"), ("Santaka tonikas", "160", "3,00", "Santaka"),
             ("Agurkas", "", "", "Rimi")]),
]

EVENT_COSTS = {  # per event: logistics, staff, branding, listing fee (EUR)
    "NG26": (1800, 3800, 2400, 3000),
    "KVN26": (1600, 2900, 2200, 2500),
    "KMV26": (400, 500, 700, 400),
    "LO26": (900, 1500, 2100, 2500),
    "DN26": (300, 400, 500, 300),
    "RP26": (400, 550, 750, 500),
}

REVENUE_SHARE = {"NG26": 0.35, "KVN26": 0.35, "KMV26": 0.32, "LO26": 0.30, "DN26": 0.30, "RP26": 0.32}

DRINKS_PER_ATTENDEE = {"outdoor": 2.2, "indoor": 1.5}
VIP_SHARE = 0.06
VOUCHERS_PER_VIP = 2
VOUCHER_REDEMPTION = 0.7
KASAPRO_RETRY_RATE = 0.025
BARFLOW_VOID_RATE = 0.015
HAPPY_HOUR = (17, 18)  # festivals only: cocktails -20 %
HAPPY_HOUR_DISCOUNT = 0.20
COCKTAILS = {"Santaka Spritz", "Midaus Mule", "Santaka G&T"}
SANTAKA_STANDALONE = ["Santaka Gira 0.5", "Rabarbarų limonadas", "Santaka Sidras 0.5", "Santaka Midus 50 ml"]
SETTLEMENT_OMISSIONS = {("LO26", "Santaka G&T")}  # organiser's statement forgets this line
TENDERS = {
    "kasapro": {"card": "card", "cash": "cash", "vip_voucher": "vip_voucher"},
    "barflow": {"card": "KORTELE", "cash": "GRYNIEJI", "vip_voucher": "KVIETIMAS"},
}


def write_csv(name, header, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    with open(OUT / name, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {name:<30} {len(rows):>7} rows")


def event_days(ev):
    return [ev[4] + timedelta(days=i) for i in range(ev[5])]


def is_festival(ev):
    return ev[5] > 1


def org_ref(ev):
    return f"{ORGANISERS[ev[2]]['prefix']}-{ev[0]}"


def sale_time(day, indoor):
    """Doors open 16:00 outdoor / 18:30 indoor; demand peaks mid-evening."""
    open_h = 16.0 if not indoor else 18.5
    hours = rng.triangular(open_h, 23.9, open_h + (4.5 if not indoor else 2.0))
    ts = datetime.combine(day, datetime.min.time()) + timedelta(hours=hours, seconds=rng.randint(0, 59))
    return ts.replace(microsecond=0)


def simulate_receipts(ev, day, tickets, vip):
    """The true sales of one event day: list of receipts, each a dict with lines of (item, qty)."""
    indoor = ev[6] == "indoor"
    bar_count = ev[9]
    target = int(tickets * DRINKS_PER_ATTENDEE[ev[6]] * rng.uniform(0.9, 1.1))
    vouchers_left = int(vip * VOUCHERS_PER_VIP * VOUCHER_REDEMPTION)
    items, weights = list(MENU), [MENU[m]["weight"] for m in MENU]
    receipts, sold = [], 0
    while sold < target:
        voucher = vouchers_left > 0 and rng.random() < 0.08
        vouchers_left -= voucher
        payment = "vip_voucher" if voucher else rng.choices(["card", "cash"], [0.88, 0.12])[0]
        n_lines = 1 if voucher else rng.choices([1, 2, 3], [0.6, 0.3, 0.1])[0]
        lines = []
        for _ in range(n_lines):
            qty = 1 if voucher else rng.choices([1, 2, 3, 4], [0.65, 0.25, 0.07, 0.03])[0]
            lines.append((rng.choices(items, weights)[0], qty))
            sold += qty
        ts = sale_time(day, indoor)
        receipts.append({
            "bar": rng.randint(1, bar_count),
            "till": rng.randint(1, 3),
            "sold_at": ts,
            "payment": payment,
            "lines": lines,
            "happy_hour": is_festival(ev) and HAPPY_HOUR[0] <= ts.hour < HAPPY_HOUR[1] and not voucher,
        })
    receipts.sort(key=lambda r: r["sold_at"])
    return receipts


def write_kasapro(ev, day, receipts, rows):
    ref = org_ref(ev)
    first_batch = f"{ref}-{day:%Y%m%d}-01"
    first_export = datetime.combine(day + timedelta(days=1), datetime.min.time()) + timedelta(hours=6)
    late_batch = f"{ref}-{day:%Y%m%d}-02"
    late_export = first_export + timedelta(days=3, hours=rng.randint(1, 8))
    day_rows, promo_rows, by_txn = [], [], defaultdict(list)
    for n, rc in enumerate(receipts, start=1):
        txn_id = f"{ref}-{day:%m%d}-{n:06d}"
        common = [ref, f"Baras {rc['bar']}", f"{rc['bar']}-{rc['till']}", txn_id]
        for line_no, (item, qty) in enumerate(rc["lines"], start=1):
            unit = MENU[item]["price"]
            discount = unit * qty if rc["payment"] == "vip_voucher" else 0.0
            row = [first_batch, first_export.isoformat(sep=" "), *common, line_no, rc["sold_at"].isoformat(sep=" "),
                   rng.choice(MENU[item]["names"]), qty, f"{unit:.2f}", f"{discount:.2f}",
                   f"{unit * qty - discount:.2f}", rc["payment"], "sale"]
            day_rows.append(row)
            by_txn[txn_id].append(row)
            if rc["happy_hour"] and item in COCKTAILS:
                adj = round(unit * HAPPY_HOUR_DISCOUNT, 2)
                promo_rows.append([late_batch, late_export.isoformat(sep=" "), *common, 90 + line_no,
                                   rc["sold_at"].isoformat(sep=" "), "HAPPY HOUR -20%", qty, f"{-adj:.2f}", "0.00",
                                   f"{-adj * qty:.2f}", rc["payment"], "promo_adjustment"])
    retried = [t for t in by_txn if rng.random() < KASAPRO_RETRY_RATE]
    dupes = [[late_batch, late_export.isoformat(sep=" "), *row[2:]] for t in retried for row in by_txn[t]]
    rows.extend(day_rows + promo_rows + dupes)


def write_barflow(ev, day, receipts, rows, receipt_seq):
    ref = org_ref(ev)
    tenders = TENDERS["barflow"]

    def emit(rc, status):
        receipt_seq[0] += 1
        receipt_no = f"BF{receipt_seq[0]:07d}"
        for position, (item, qty) in enumerate(rc["lines"], start=1):
            unit_net = round(MENU[item]["price"] / (1 + VAT) * 100)
            discount = unit_net * qty if rc["payment"] == "vip_voucher" else 0
            line_net = unit_net * qty - discount
            rows.append([receipt_no, position, ref, f"B{rc['bar']:02d}", rc["sold_at"].strftime("%d.%m.%Y %H:%M:%S"),
                         MENU[item]["plu"], item.upper(), qty, unit_net, discount, line_net, round(line_net * VAT),
                         tenders[rc["payment"]], status])

    for rc in receipts:
        if rng.random() < BARFLOW_VOID_RATE:
            emit(rc, "VOID")  # rung up, then cancelled and re-entered at the till
        emit(rc, "OK")


def main():
    print(f"Writing to {OUT}")
    write_csv(
        "santaka_events.csv",
        ["event_code", "event_name", "organiser_name", "organiser_event_ref", "venue", "city",
         "start_date", "end_date", "indoor_outdoor", "capacity_per_day"],
        [[e[0], e[1], e[2], org_ref(e), e[3], "Kaunas", e[4].isoformat(), event_days(e)[-1].isoformat(), e[6], e[7]]
         for e in EVENTS],
    )
    write_csv(
        "santaka_contracts.csv",
        ["event_code", "revenue_share_pct", "share_basis", "signed_on"],
        [[e[0], REVENUE_SHARE[e[0]], "Santaka products, net sales excl. VAT",
          (e[4] - timedelta(days=rng.randint(45, 120))).isoformat()] for e in EVENTS],
    )
    write_csv(
        "santaka_event_costs.csv",
        ["event_code", "cost_type", "amount_eur"],
        [[code, t, amt] for code, costs in EVENT_COSTS.items()
         for t, amt in zip(("logistics", "staff", "branding", "listing_fee"), costs)],
    )
    write_csv(
        "santaka_products.csv",
        ["sku", "product_name", "category", "abv_pct", "pack", "pack_volume_ml", "list_price_eur_per_l",
         "production_cost_eur_per_l"],
        PRODUCTS,
    )
    recipe_rows = []
    for cocktail, lines in RECIPES:
        for i, (ingredient, ml, cost, supplier) in enumerate(lines):
            recipe_rows.append([len(recipe_rows) + 1, cocktail if i == 0 else "", ingredient, ml, cost, supplier])
    write_csv("bar_recipes.csv", ["nr", "kokteilis", "ingredientas", "kiekis_ml", "kaina_eur_l", "tiekejas"], recipe_rows)

    ticket_rows, kasapro_rows, barflow_rows, truth = [], [], [], []
    receipt_seq = [0]
    for ev in EVENTS:
        cap, fill = ev[7], ev[8]
        for day in event_days(ev):
            tickets = int(cap * rng.uniform(fill - 0.05, min(fill + 0.05, 1.0)))
            vip = int(tickets * VIP_SHARE)
            ticket_rows.append([org_ref(ev), day.isoformat(), "general", tickets - vip])
            ticket_rows.append([org_ref(ev), day.isoformat(), "vip", vip])
            receipts = simulate_receipts(ev, day, tickets, vip)
            truth.extend((ev, rc) for rc in receipts)
            if ORGANISERS[ev[2]]["epos"] == "kasapro":
                write_kasapro(ev, day, receipts, kasapro_rows)
            else:
                write_barflow(ev, day, receipts, barflow_rows, receipt_seq)

    write_csv("organiser_ticket_sales.csv", ["organiser_event_ref", "event_date", "ticket_type", "tickets_sold"],
              ticket_rows)
    kasapro_rows.sort(key=lambda r: (r[0], r[7], r[5], r[6]))
    write_csv(
        "kasapro_sales_export.csv",
        ["export_batch_id", "exported_at", "organiser_event_ref", "bar_name", "till_id", "transaction_id",
         "line_no", "sold_at", "item_name", "quantity", "unit_price", "discount_amount", "line_amount",
         "payment_method", "line_type"],
        kasapro_rows,
    )
    write_csv(
        "barflow_receipt_lines.csv",
        ["receipt_no", "position", "location_id", "bar_code", "created_local", "plu", "item_label", "qty",
         "unit_net_cents", "discount_net_cents", "line_net_cents", "vat_cents", "tender", "status"],
        barflow_rows,
    )
    write_settlements(truth)
    story_check(truth)


def recipe_shares():
    """Santaka share of each cocktail as (by volume, by ingredient cost)."""
    shares = {}
    for cocktail, lines in RECIPES:
        parts = [(float(ml or 0), float(ml or 0) * float(cost.replace(",", ".") or 0) / 1000, sup == "Santaka")
                 for _, ml, cost, sup in lines]
        tv, tc = sum(p[0] for p in parts), sum(p[1] for p in parts)
        shares[cocktail] = (sum(p[0] for p in parts if p[2]) / tv, sum(p[1] for p in parts if p[2]) / tc)
    return shares


def allocations():
    """Santaka share per menu item as (by volume, by ingredient cost); third-party items absent."""
    shares = recipe_shares()
    alloc = {"Santaka Spritz": shares["Santaka Spritz"], "Midaus Mule": shares["Midaus Mule"],
             "Santaka G&T": shares["G&T"]}
    alloc.update({m: (1.0, 1.0) for m in SANTAKA_STANDALONE})
    return alloc


def line_net(rc, item, qty):
    """What the organiser actually took for a line, net of VAT: after happy hour, vouchers at 0."""
    if rc["payment"] == "vip_voucher":
        return 0.0
    gross = MENU[item]["price"] * qty * (1 - HAPPY_HOUR_DISCOUNT if rc["happy_hour"] and item in COCKTAILS else 1)
    return gross / (1 + VAT)


def write_settlements(truth):
    """Organiser's settlement statement: their own calculation, by volume split, one row per event and menu item."""
    alloc = allocations()
    qty_sum, sales_sum = defaultdict(int), defaultdict(float)
    for ev, rc in truth:
        for item, qty in rc["lines"]:
            if item in alloc:
                qty_sum[(ev[0], item)] += qty
                sales_sum[(ev[0], item)] += line_net(rc, item, qty) * alloc[item][0]
    rows = []
    for ev in EVENTS:
        issued = event_days(ev)[-1] + timedelta(days=14)
        pct = REVENUE_SHARE[ev[0]]
        for item in alloc:
            if (ev[0], item) in SETTLEMENT_OMISSIONS or (ev[0], item) not in qty_sum:
                continue
            sales = round(sales_sum[(ev[0], item)], 2)
            rows.append([org_ref(ev), issued.isoformat(), item, qty_sum[(ev[0], item)], f"{sales:.2f}",
                         round(pct * 100), f"{round(sales * pct, 2):.2f}"])
    write_csv("organiser_settlements.csv",
              ["renginys", "israsymo_data", "pozicija", "parduota_vnt", "pardavimai_be_pvm", "dalis_proc",
               "moketina_suma"], rows)


def story_check(truth):
    """'Truth' numbers for the talk from the simulated sales, before any export mess."""
    shares = recipe_shares()
    alloc = allocations()

    totals = defaultdict(lambda: [0.0, 0.0, 0.0])
    for ev, rc in truth:
        if rc["payment"] == "vip_voucher":
            continue
        for item, qty in rc["lines"]:
            if item not in alloc:
                continue
            net = line_net(rc, item, qty)
            gross = net * (1 + VAT)
            vol, cost = alloc[item]
            t = totals[ev[0]]
            t[0] += net * vol
            t[1] += net * cost
            t[2] += (gross - net) * cost if ORGANISERS[ev[2]]["epos"] == "kasapro" else 0.0

    print("\nStory check on attributed sales (deduplicated, net of VAT, after promos, vouchers at 0):")
    print(f"  {'event':<7}{'by volume €':>13}{'by cost €':>12}{'split gap €':>13}{'VAT gap €':>11}")
    for code, (vol, cost, vat_gap) in totals.items():
        print(f"  {code:<7}{vol:>13,.0f}{cost:>12,.0f}{cost - vol:>13,.0f}{vat_gap:>11,.0f}")
    for c, (v, k) in shares.items():
        print(f"  recipe {c:<16} volume share {v:.0%}  cost share {k:.0%}")


if __name__ == "__main__":
    main()
