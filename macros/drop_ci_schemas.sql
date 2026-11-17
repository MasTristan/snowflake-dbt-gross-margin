{#-
  Drops target.schema and every schema of target.database named target.schema || '_...'
  (case-insensitive). The '_' boundary keeps dbt_ci_pr_1 from matching dbt_ci_pr_12
  of a concurrent PR. CI only: refuses to run on any other target.
  Usage: dbt run-operation drop_ci_schemas --profiles-dir ci
-#}
{% macro drop_ci_schemas() %}
    {% if target.name != 'ci' %}
        {% do exceptions.raise_compiler_error("drop_ci_schemas only runs on target 'ci', got '" ~ target.name ~ "'") %}
    {% endif %}

    {% set find_schemas %}
        select schema_name
        from {{ target.database }}.information_schema.schemata
        where upper(schema_name) = upper('{{ target.schema }}')
           or startswith(upper(schema_name), upper('{{ target.schema }}') || '_')
    {% endset %}

    {% for row in run_query(find_schemas).rows %}
        {% do log('Dropping schema ' ~ target.database ~ '.' ~ row[0], info=True) %}
        {% do run_query('drop schema if exists ' ~ adapter.quote(target.database) ~ '.' ~ adapter.quote(row[0]) ~ ' cascade') %}
    {% endfor %}
{% endmacro %}
