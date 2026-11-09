{# Creates a Snowflake Cortex agent from the model body (the agent specification YAML). Config: meta.display_name, meta.agent_comment. #}
{% materialization cortex_agent, adapter='snowflake' -%}
    {%- set agent_meta = config.get('meta', {}) -%}
    {%- set display_name = agent_meta.get('display_name', this.identifier) -%}
    {%- set agent_comment = agent_meta.get('agent_comment', '') -%}
    {%- set target_relation = this.incorporate(type='view') -%}
    {% call statement('main') -%}
        create or replace agent {{ this }}
            comment = '{{ agent_comment | replace("'", "''") }}'
            profile = '{"display_name": "{{ display_name }}"}'
            from specification
            $$
{{ sql }}
            $$
    {%- endcall %}
    {{ return({'relations': [target_relation]}) }}
{%- endmaterialization %}
