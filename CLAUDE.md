# CLAUDE.md

Demo dbt Fusion project for the Helmes × KKPDA AI & data event (2026-11-24). Fictional Kaunas drinks maker "Santaka" supplies concerts and festivals; mocked multi-source data with deliberate quality issues flows bronze → silver → gold (Kimball) → platinum (Snowflake semantic view for Cortex Analyst).

## Working rules

- Direct mode by default. Use `.claude/guidelines/socratic-method.md` only when a genuinely new concept comes up (e.g. demand forecasting).
- Never run dbt or SQL commands; give the user the command to run and wait for the reported result.
- In model SQL, comment with Jinja `{# #}` blocks, not `--`.
- SQL style: follow `.claude/guidelines/sql-guidelines.md` (`c_` CTEs, `_step_XX` pipelines, qualified columns, `from`/`join` on their own line). Use `{# #}` instead of `--` comments and no trailing semicolons. Gold models use `dim_`/`fct_`/`bridge_` prefixes; surrogate keys end in `_xid`.

## Layout

- `seeds/raw/` — generated (`scripts/generate_mock_data.py`) and public source data, schema `raw`; `seeds/reference/` — hand-kept mappings, schema `reference`
- `models/bronze/<source>/<source>__<entity>` — typed 1:1 views per source system
- `models/silver/<domain>/_private/<source>/stg_<domain>__<source>_<entity>` — one leg per source conformed to the shape gold needs; `models/silver/<domain>/<domain>__<entity>` — unions legs and holds all business rules. Business codes only, no hashes
- `models/gold/` — Kimball dims/facts/bridges with enforced contracts; `_private/stg_gold__*` resolves `_xid` keys via `md5_composite_keys`, `'-1'` for unknown members. No business logic in gold
- `models/platinum/` — semantic views (`sem_*`) and Cortex agents (`agent_*`, `cortex_agent` materialization; agents are blocked on the trial account)
- `streamlit/` — side-by-side demo app (naive vs clean Cortex Analyst), deployed with `snow streamlit deploy --replace` from that folder (connection `santaka` in `~/.snowflake/config.toml`)
- `macros/generate_schema_name.sql` keeps schema names unprefixed
- `profiles.yml` — local only (git-ignored). Copy `profiles.example.yml` and fill in account, login and key path; key-pair auth, warehouse `SANTAKA_DEMO_WH`, database `SANTAKA_DEMO`. Run dbt with `--profiles-dir .`
