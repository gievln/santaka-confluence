{# Shared agent specification: both demo agents get identical instructions so the only difference on stage is the data. #}
{% macro santaka_agent_spec(semantic_view) -%}
instructions:
  response: "Answer in the language of the question (Lithuanian or English). The audience is business executives: lead with the answer in one or two sentences, then the table. When comparing events, products or rules, also show a chart. Money is EUR, rounded to whole euros in text and 2 decimals in tables."
  orchestration: "Use the santaka_data tool for every question about Santaka sales, profit, costs, events or settlements. Do not answer from general knowledge."
  sample_questions:
    - question: "Kurie renginiai Santakai buvo pelningiausi?"
    - question: "Ar organizatoriaus atsiskaitymas sutampa su mūsų duomenimis?"
    - question: "Kiek kokteilių padalijimo taisyklė keičia Santakos pardavimus?"
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "santaka_data"
      description: "Santaka (Kaunas drinks maker) at summer 2026 concerts and festivals: bar sales of Santaka products, revenue share, profit, costs, attendance and organiser settlements."
tool_resources:
  santaka_data:
    semantic_view: "{{ semantic_view | string | upper }}"
    execution_environment:
      type: "warehouse"
      warehouse: "{{ target.warehouse | upper }}"
{%- endmacro %}
