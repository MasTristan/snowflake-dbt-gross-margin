{% macro calculate_net_revenue(price_col, discount_col) %}
    {{ price_col }} * (1 - coalesce({{ discount_col }}, 0))
{% endmacro %}
