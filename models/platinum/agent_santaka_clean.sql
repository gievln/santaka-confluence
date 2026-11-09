{{ config(
    materialized='cortex_agent',
    static_analysis='off',
    meta={
        'display_name': 'Santaka AI – sutvarkyti duomenys',
        'agent_comment': 'Snowflake Intelligence agent on the cleaned gold layer (sem_santaka).',
    },
) }}
{{ santaka_agent_spec(ref('sem_santaka')) }}
