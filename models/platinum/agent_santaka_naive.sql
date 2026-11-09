{{ config(
    materialized='cortex_agent',
    static_analysis='off',
    meta={
        'display_name': 'Santaka AI – tiesiai iš eksportų',
        'agent_comment': 'Snowflake Intelligence agent on the raw exports (sem_santaka_naive), for the before/after demo.',
    },
) }}
{{ santaka_agent_spec(ref('sem_santaka_naive')) }}
