"""Santaka demo: one question, two Cortex Analyst answers side by side (raw exports vs cleaned data)."""

import json
import os

import altair as alt
import pandas as pd
import requests
import streamlit as st
from snowflake.snowpark.context import get_active_session

try:
    import _snowflake  # warehouse runtime only
except ImportError:
    _snowflake = None

ANALYST_API = "/api/v2/cortex/analyst/message"
API_TIMEOUT_MS = 50_000
PANELS = {
    "naive": {
        "title": "Tiesiai iš eksportų",
        "caption": "AI prijungtas prie neapdorotų organizatorių EPOS eksportų",
        "semantic_view": "SANTAKA_DEMO.PLATINUM.SEM_SANTAKA_NAIVE",
        "colour": "#c0392b",
    },
    "clean": {
        "title": "Sutvarkyti duomenys",
        "caption": "Tas pats AI, bet duomenys išvalyti, suderinti ir aprašyti",
        "semantic_view": "SANTAKA_DEMO.PLATINUM.SEM_SANTAKA",
        "colour": "#1e8449",
    },
}
SAMPLE_QUESTIONS = {
    "Pelningiausi renginiai": "Kurie renginiai Santakai buvo pelningiausi?",
    "Ar atsiskaitymas sutampa?": "Ar organizatoriaus atsiskaitymas sutampa su mūsų duomenimis?",
    "Kokteilių taisyklė": "Kiek kokteilių padalijimo taisyklė keičia Santakos pardavimus?",
}
COLUMN_LABELS = {
    "EVENT_NAME": "Renginys",
    "EVENT_TYPE": "Tipas",
    "AGREED_RULE": "Sutarta taisyklė",
    "MENU_ITEM_NAME": "Meniu pozicija",
    "ITEM_NAME": "Pozicija",
    "PROFIT": "Pelnas",
    "SANTAKA_REVENUE": "Santakos pajamos",
    "SANTAKA_SALES": "Santakos pardavimai",
    "TOTAL_SALES": "Visi pardavimai",
    "TOTAL_EVENT_COSTS": "Renginio išlaidos",
    "PROFIT_RECEIVED_EUR": "Pelnas (faktiškai gauta)",
    "TOTAL_PROFIT_RECEIVED": "Pelnas (faktiškai gauta)",
    "PROFIT_BY_VOLUME_ORGANISER_RULE_EUR": "Pelnas pagal tūrį (organizatoriaus taisyklė)",
    "TOTAL_PROFIT_VOLUME": "Pelnas pagal tūrį (organizatoriaus taisyklė)",
    "PROFIT_BY_COST_SANTAKA_RULE_EUR": "Pelnas pagal savikainą (Santakos taisyklė)",
    "TOTAL_PROFIT_COST": "Pelnas pagal savikainą (Santakos taisyklė)",
    "RECONCILIATION_STATUS": "Būsena",
    "ORGANISER_STATEMENT_EUR": "Organizatoriaus ataskaita",
    "SANTAKA_FIGURE_SAME_RULE_EUR": "Mūsų skaičiavimas (ta pati taisyklė)",
    "UNDERPAID_EUR": "Nesumokėta",
    "SANTAKA_SALES_BY_VOLUME_EUR": "Pardavimai pagal tūrį",
    "SANTAKA_SALES_BY_COST_EUR": "Pardavimai pagal savikainą",
    "SPLIT_RULE_DIFFERENCE_EUR": "Taisyklių skirtumas",
}
VALUE_LABELS = {
    "not agreed": "nesutarta",
    "festival": "festivalis",
    "concert": "koncertas",
    "matched": "sutampa",
    "mismatch": "nesutampa",
    "missing_from_statement": "trūksta ataskaitoje",
}
# Which measure the chart shows when an answer has several: first match wins.
CHART_PRIORITY = ["PROFIT_RECEIVED", "UNDERPAID", "SPLIT_RULE_DIFFERENCE", "PROFIT", "DATA_GAP", "SALES", "REVENUE"]
LABEL_PRIORITY = ["EVENT_NAME", "MENU_ITEM_NAME", "ITEM_NAME"]
NOT_MONEY = ("UNITS", "QUANTITY", "TICKETS", "SERVES", "LITRES", "LINES", "COUNT", "DAYS", "CAPACITY", "PCT")

st.set_page_config(page_title="Santaka", layout="wide")
st.markdown(
    """
    <style>
    html, body, [class*="st-"] { font-size: 20px; }
    h1 { font-size: 2.1rem !important; }
    .panel-title { font-size: 1.6rem; font-weight: 700; color: white; padding: 0.4rem 0.9rem; border-radius: 0.4rem; }
    .question { font-size: 1.5rem; font-weight: 600; text-align: center; margin: 0.6rem 0 1rem; }
    table { font-size: 1rem !important; }
    </style>
    """,
    unsafe_allow_html=True,
)
session = get_active_session()

if "history" not in st.session_state:
    st.session_state.history = {key: [] for key in PANELS}
    st.session_state.turns = []


def call_analyst(body: dict) -> tuple:
    """POST to Cortex Analyst; warehouse runtime has a helper, container runtime uses the session token."""
    if _snowflake is not None:
        response = _snowflake.send_snow_api_request("POST", ANALYST_API, {}, {}, body, None, API_TIMEOUT_MS)
        return response["status"], json.loads(response["content"])
    host = os.getenv("SNOWFLAKE_HOST") or session.connection.host
    response = requests.post(
        f"https://{host}{ANALYST_API}",
        json=body,
        headers={
            "Authorization": f'Snowflake Token="{session.connection.rest.token}"',
            "Content-Type": "application/json",
        },
        timeout=API_TIMEOUT_MS / 1000,
    )
    return response.status_code, response.json()


def ask_analyst(panel_key: str, question: str) -> dict:
    """Send the question with this panel's conversation history; run the returned SQL."""
    messages = st.session_state.history[panel_key] + [
        {"role": "user", "content": [{"type": "text", "text": question}]}
    ]
    body = {"messages": messages, "semantic_view": PANELS[panel_key]["semantic_view"]}
    status, payload = call_analyst(body)
    if status >= 400:
        return {"error": payload.get("message", str(payload))}

    content = payload["message"]["content"]
    st.session_state.history[panel_key] = messages + [{"role": "analyst", "content": content}]
    answer = {
        "text": "\n\n".join(item["text"] for item in content if item["type"] == "text"),
        "sql": next((item["statement"] for item in content if item["type"] == "sql"), None),
    }
    if answer["sql"]:
        try:
            answer["data"] = numeric_cleanup(session.sql(answer["sql"]).to_pandas())
        except Exception as exc:  # shown in the panel instead of crashing the demo
            answer["sql_error"] = str(exc)
    return answer


def numeric_cleanup(df: pd.DataFrame) -> pd.DataFrame:
    """Snowflake NUMBERs can arrive as Decimal objects; make fully numeric columns real floats."""
    for column in df.columns:
        if pd.api.types.is_bool_dtype(df[column]):
            continue
        converted = pd.to_numeric(df[column], errors="coerce")
        if converted.notna().all():
            df[column] = converted.astype(float)
    return df


def measures(df: pd.DataFrame) -> list:
    return [c for c in df.columns if pd.api.types.is_float_dtype(df[c])]


def chart_columns(df: pd.DataFrame):
    """Pick the label column and the single measure to chart, or None if the answer is not chartable."""
    numeric = measures(df)
    labels = [c for c in df.columns if c not in numeric and df[c].dtype == object]
    if not numeric or not labels or len(df) > 15:
        return None
    label = next((c for p in LABEL_PRIORITY for c in labels if c == p), labels[0])
    measure = next((c for p in CHART_PRIORITY for c in numeric if p in c), numeric[0])
    return label, measure


def label_of(column: str) -> str:
    """Lithuanian label; Cortex sometimes appends _EUR, so try the name without it too."""
    for key in (column, column.removesuffix("_EUR")):
        if key in COLUMN_LABELS:
            return COLUMN_LABELS[key]
    return column.removesuffix("_EUR").replace("_", " ").capitalize()


def euro(value: float) -> str:
    sign = "−" if value < 0 else ""
    return f"{sign}€{abs(value):,.0f}".replace(",", " ")


def formatter(column: str):
    """Euros for money columns, plain thousands for counts and volumes."""
    if any(word in column for word in NOT_MONEY):
        return lambda value: f"{value:,.0f}".replace(",", " ")
    return euro


def draw_chart(df: pd.DataFrame, label: str, measure: str, domain: list) -> None:
    """One bar per row, green above zero, red below, value printed on the bar; shared scale across panels."""
    data = pd.DataFrame({"label": df[label], "value": df[measure]})
    data["text"] = data["value"].map(formatter(measure))
    order = list(data.sort_values("value", ascending=False)["label"])
    base = alt.Chart(data).encode(
        y=alt.Y("label:N", sort=order, title=None, axis=alt.Axis(labelLimit=260, labelFontSize=16)),
        x=alt.X("value:Q", title=None, scale=alt.Scale(domain=domain), axis=alt.Axis(format="~s", labelFontSize=14)),
    )
    bars = base.mark_bar(size=26).encode(
        color=alt.condition("datum.value >= 0", alt.value("#27ae60"), alt.value("#c0392b")),
    )
    text = base.mark_text(align="left", dx=6, fontSize=16, fontWeight="bold").encode(text="text:N")
    st.markdown(f"**{label_of(measure)}**")
    st.altair_chart((bars + text).properties(height=46 * len(data) + 20), use_container_width=True)


def display_table(df: pd.DataFrame) -> pd.DataFrame:
    shown = df.copy()
    for column in shown.columns:
        if pd.api.types.is_float_dtype(shown[column]):
            shown[column] = shown[column].map(formatter(column))
        elif shown[column].dtype == object:
            shown[column] = shown[column].map(lambda v: VALUE_LABELS.get(v, v) if isinstance(v, str) else v)
    return shown.rename(columns=label_of)


def shared_domain(turn: dict) -> list:
    """Same x-axis for both panels so the size difference between answers is visible."""
    values = [0.0]
    for answer in turn["answers"].values():
        picked = chart_columns(answer["data"]) if "data" in answer else None
        if picked:
            values.extend(answer["data"][picked[1]].tolist())
    low, high = min(values), max(values)
    pad = (high - low) * 0.18 or 1
    return [low - (pad if low < 0 else 0), high + pad]


def render_answer(answer: dict, domain: list) -> None:
    if "error" in answer:
        st.error(answer["error"])
        return
    if "sql_error" in answer:
        st.error(answer["sql_error"])
    if "data" in answer:
        picked = chart_columns(answer["data"])
        if picked:
            draw_chart(answer["data"], picked[0], picked[1], domain)
        with st.expander("Lentelė", expanded=not picked):
            st.table(display_table(answer["data"]))
    with st.expander("Kaip AI suprato klausimą"):
        st.write(answer.get("text") or "–")
        if answer.get("sql"):
            st.code(answer["sql"], language="sql")


def ask_both(question: str) -> None:
    answers = {}
    for key in PANELS:
        with st.spinner(f"{PANELS[key]['title']}: galvoja…"):
            answers[key] = ask_analyst(key, question)
    st.session_state.turns.append({"question": question, "answers": answers})


st.title("Dirbtinis intelektas atsako tiksliai tiek, kiek tikslūs yra jam pateikti duomenys")
st.caption("Santaka – Kauno gėrimų gamintoja · 2026 m. vasaros koncertai ir festivaliai")

button_columns = st.columns(len(SAMPLE_QUESTIONS) + 1)
for column, (short, full) in zip(button_columns, SAMPLE_QUESTIONS.items()):
    if column.button(short, use_container_width=True):
        ask_both(full)
if button_columns[-1].button("🔄 Iš naujo", use_container_width=True):
    st.session_state.history = {key: [] for key in PANELS}
    st.session_state.turns = []

question = st.chat_input("Užduokite klausimą apie Santakos renginius…")
if question:
    ask_both(question)

if st.session_state.turns:
    latest = st.session_state.turns[-1]
    st.markdown(f"<div class='question'>❓ {latest['question']}</div>", unsafe_allow_html=True)
    domain = shared_domain(latest)
    for key, column in zip(PANELS, st.columns(2, gap="large")):
        with column:
            st.markdown(
                f"<div class='panel-title' style='background:{PANELS[key]['colour']}'>{PANELS[key]['title']}</div>",
                unsafe_allow_html=True,
            )
            st.caption(PANELS[key]["caption"])
            render_answer(latest["answers"][key], domain)

    if len(st.session_state.turns) > 1:
        with st.expander("Ankstesni klausimai"):
            for turn in reversed(st.session_state.turns[:-1]):
                st.markdown(f"**❓ {turn['question']}**")
                for key, column in zip(PANELS, st.columns(2)):
                    with column:
                        st.caption(PANELS[key]["title"])
                        if "data" in turn["answers"][key]:
                            st.table(display_table(turn["answers"][key]["data"]))
                        elif "error" in turn["answers"][key]:
                            st.error(turn["answers"][key]["error"])
                st.divider()
