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
    },
    "clean": {
        "title": "Sutvarkyti duomenys",
        "caption": "Tas pats AI, bet duomenys išvalyti, suderinti ir aprašyti",
        "semantic_view": "SANTAKA_DEMO.PLATINUM.SEM_SANTAKA",
    },
}
SAMPLE_QUESTIONS = [
    "Kurie renginiai Santakai buvo pelningiausi?",
    "Ar organizatoriaus atsiskaitymas sutampa su mūsų duomenimis?",
    "Kiek kokteilių padalijimo taisyklė keičia Santakos pardavimus?",
]

st.set_page_config(page_title="Santaka", layout="wide")
session = get_active_session()

if "history" not in st.session_state:
    st.session_state.history = {key: [] for key in PANELS}
    st.session_state.turns = {key: [] for key in PANELS}


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
        "suggestions": next((item["suggestions"] for item in content if item["type"] == "suggestions"), []),
    }
    if answer["sql"]:
        try:
            answer["data"] = session.sql(answer["sql"]).to_pandas()
        except Exception as exc:  # shown in the panel instead of crashing the demo
            answer["sql_error"] = str(exc)
    return answer


def numeric_columns(df: pd.DataFrame) -> list:
    """Columns that are fully numeric; Snowflake NUMBERs can arrive as Decimal objects."""
    columns = []
    for column in df.columns:
        if pd.api.types.is_bool_dtype(df[column]):
            continue
        converted = pd.to_numeric(df[column], errors="coerce")
        if converted.notna().all():
            df[column] = converted
            columns.append(column)
    return columns


def draw_chart(df: pd.DataFrame) -> None:
    """Horizontal bars per label row, one colour per numeric measure."""
    measures = numeric_columns(df)
    labels = [c for c in df.columns if c not in measures and not pd.api.types.is_bool_dtype(df[c])]
    if not measures or not labels or len(df) > 25:
        return
    label = labels[0]
    long = df.melt(id_vars=[label], value_vars=measures, var_name="measure", value_name="value")
    long["measure"] = long["measure"].str.replace("_", " ").str.lower()
    chart = (
        alt.Chart(long)
        .mark_bar()
        .encode(
            x=alt.X("value:Q", title=None),
            y=alt.Y("measure:N", title=None, axis=alt.Axis(labels=False, ticks=False)),
            color=alt.Color("measure:N", legend=alt.Legend(orient="bottom", title=None, columns=1)),
            row=alt.Row(f"{label}:N", title=None, sort=list(df[label]),
                        header=alt.Header(labelAngle=0, labelAlign="left")),
            tooltip=[label, "measure", alt.Tooltip("value:Q", format=",.2f")],
        )
        .properties(width=420, height=18 * len(measures))
    )
    st.altair_chart(chart)


def render_turn(turn: dict) -> None:
    st.markdown(f"**❓ {turn['question']}**")
    answer = turn["answer"]
    if "error" in answer:
        st.error(answer["error"])
        return
    if answer["text"]:
        st.info(answer["text"])
    if "sql_error" in answer:
        st.error(answer["sql_error"])
    if "data" in answer:
        st.dataframe(answer["data"], use_container_width=True, hide_index=True)
        draw_chart(answer["data"].copy())
    if answer["suggestions"]:
        st.caption("Galimi klausimai: " + " · ".join(answer["suggestions"]))
    if answer["sql"]:
        with st.expander("SQL"):
            st.code(answer["sql"], language="sql")


def ask_both(question: str) -> None:
    for key in PANELS:
        with st.spinner(f"{PANELS[key]['title']}: galvoja…"):
            st.session_state.turns[key].append({"question": question, "answer": ask_analyst(key, question)})


st.title("Dirbtinis intelektas atsako tiksliai tiek, kiek tikslūs yra jam pateikti duomenys")
st.caption("Santaka – Kauno gėrimų gamintoja, 2026 m. vasaros koncertai ir festivaliai")

sample_columns = st.columns(len(SAMPLE_QUESTIONS) + 1)
for column, sample in zip(sample_columns, SAMPLE_QUESTIONS):
    if column.button(sample, use_container_width=True):
        ask_both(sample)
if sample_columns[-1].button("🔄 Iš naujo", use_container_width=True):
    st.session_state.history = {key: [] for key in PANELS}
    st.session_state.turns = {key: [] for key in PANELS}

question = st.chat_input("Užduokite klausimą apie Santakos renginius…")
if question:
    ask_both(question)

for key, column in zip(PANELS, st.columns(2)):
    with column:
        st.subheader(PANELS[key]["title"])
        st.caption(PANELS[key]["caption"])
        for turn in reversed(st.session_state.turns[key]):
            render_turn(turn)
            st.divider()
