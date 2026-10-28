{# Surrogate key: md5 of one column or a list joined with '~'; nulls hash as empty strings. Unknown members ('-1') are handled by the caller. #}
{%- macro md5_composite_keys(columns) -%}
    {%- if columns is string -%}
        {%- set columns = [columns] -%}
    {%- endif -%}
    md5(concat_ws('~', {% for column in columns %}coalesce(({{ column }})::varchar, ''){{ ', ' if not loop.last }}{% endfor %}))
{%- endmacro -%}
