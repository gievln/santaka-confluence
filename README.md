# Santaka · „Dirbtinis intelektas atsako tiksliai tiek, kiek tikslūs yra jam pateikti duomenys“

Demo and slides for the Helmes × KKPDA AI & data event in Kaunas, 2026-11-24.

Santaka is a fictional Kaunas drinks maker that supplies concerts and festivals and earns a share of the organisers' bar sales. Its data arrives from seven messy sources. The talk shows the same AI question answered twice: once on the raw exports and once after the data is cleaned layer by layer.

## Slides

**[presentation/santaka_talk.html](presentation/santaka_talk.html)** – a single offline HTML file. Download it and open it in Chrome; GitHub shows only the source.

| Key | Action |
|---|---|
| → · Space · PageDown | next step |
| ← · PageUp | previous step |
| F | fullscreen |
| Home | back to the start |

The URL hash `#scene.step` (for example `#19.1`) jumps straight to a step, which is handy when rehearsing.

## Flow

| # | Section | Slides | Live |
|---|---|---|---|
| 1 | Išgalvota įmonė: Santaka | who Santaka is, how it earns, the profit formula | |
| 2 | Iš kur atkeliauja duomenys | seven sources flowing into a muddy lake; how the demo is built (CSV → Snowflake → semantic view → Cortex Analyst → Streamlit); the app is only a window onto Cortex Analyst | ✓ |
| 3 | Klausimai D.I. – naudojant originalius duomenis | the naive AI answers fast: every event is profitable | ✓ |
| 4 | Nesutvarkytų duomenų problemos | seven errors hidden in the data | |
| 5 | Valome sluoksnis po sluoksnio | bronze → silver (one error per step), star schema, Kimball and its alternatives → gold contract → semantic layer; after each layer the river returns with a new filter; ends with the medallion architecture | ✓ |
| 6 | Tas pats klausimas – du D.I. | naive vs clean answer side by side | ✓ |
| 7 | Ką gali nuspręsti tik žmonės | the cocktail split rule (€1.59 or €2.39 per spritz); one event is profitable or not depending on the unagreed rule | |
| 8 | Kas toliau: prognozės | *(draft)* | |
| 9 | Klausimai | | |

## Demo

| Part | Where |
|---|---|
| Mock data generator | `scripts/generate_mock_data.py` → `seeds/raw/` |
| dbt Fusion project: bronze → silver → gold (Kimball) → platinum | `models/` |
| Semantic views for Cortex Analyst: naive and clean | `models/platinum/sem_santaka*.sql` |
| Side-by-side Streamlit app | `streamlit/` |

```
cp profiles.example.yml profiles.yml   # fill in account, login and key path
dbt deps --profiles-dir .
dbt build --profiles-dir .
cd streamlit && snow streamlit deploy --replace --open
```

All companies and numbers are generated. Event venues are real Kaunas places. Santaka is not connected to any real organisation.
