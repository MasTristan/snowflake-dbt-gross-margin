{#-
  Schema isolation per target:
  - no custom schema: use target.schema
  - prod: use the custom schema as is (ANALYTICS.STAGING / ANALYTICS.MARTS, read by the dashboard)
  - any other target (ci, dev): prefix with target.schema so runs never touch prod schemas
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema ~ '_' ~ (custom_schema_name | trim) }}
    {%- endif -%}
{%- endmacro %}
