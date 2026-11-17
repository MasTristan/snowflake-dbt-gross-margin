# Design notes

Technical lessons from building this pipeline, grouped by theme. They complement the decision table in the [README](../README.md).

## Composite-key join on `partsupp`

In TPC-H, one part can be supplied by several suppliers at different costs. `fct_sales` needs the cost of the specific supplier on each order line, so the join to `stg_partsupp` must use (`part_key`, `supplier_key`). Joining on `part_key` alone would fan out the fact table and attach the wrong cost, and the margin would be corrupted without any error.

Two singular tests now guard this: `assert_unique_partsupp_grain` checks the pair is unique upstream, and `assert_unique_fct_sales_grain` checks the fact still has one row per order line after the join.

## Incremental model: proving it, then fixing its weakness

`fct_sales` was first built as an incremental model with a filter anchored on the current max `ship_date`. The proof that the filter worked was the second run: the first run loaded about 6M rows, and the immediate second run touched 0 rows because nothing new had arrived.

That version had a weakness: a line arriving late, with a `ship_date` before the current max, would never be loaded. The current version uses `incremental_strategy='merge'` on (`order_key`, `line_number`) and reloads the last `lookback_days` (3) days before the max `ship_date`. Late lines are absorbed, and reloading a line already present updates it instead of duplicating it. The CI build workflow runs a full build and then a second pass on `fct_sales+` to exercise this path.

The remaining blind spot is documented: a change of `supply_cost` or `order_status` on a line outside the lookback window is not propagated. A scheduled `--full-refresh` realigns history.

## `qualify` for deduplication

`stg_lineitem` keeps one row per (`order_key`, `line_number`) with `qualify row_number() over (partition by ... order by l_shipdate desc) = 1`. It is Snowflake-native and avoids a subquery that computes `row_number()` and filters it in an outer `where`. Deduplicating in staging means every downstream model can rely on the grain.

## Generic and singular tests

Generic tests (`not_null`, `unique`, `relationships`, `accepted_values`) cover column-level contracts. Singular tests cover rules that involve several columns or models: grain after a join, value bounds, date coverage. When a rule does not fit a generic test, a SQL file in `tests/` that returns the offending rows is the simplest form.

## dbt 1.11 deprecation: `arguments:` on generic tests

dbt 1.11 emits `MissingArgumentsPropertyInGenericTestDeprecation` when the parameters of a generic test (`to` and `field` for `relationships`, `values` for `accepted_values`) are written directly under the test instead of nested under `arguments:`. All tests are now written with `arguments:`. CI runs `dbt parse --warn-error`, so a new deprecation warning fails the build instead of piling up.

## Checking that physical schemas match the code

The intent was staging and marts in separate schemas. Looking at what the warehouse actually contained showed that the `generate_schema_name` override combined with the per-folder `+schema` config produced `STAGING` and `MARTS` as expected. Assumptions about the warehouse are worth checking against the warehouse, not only against the code.

## `generate_schema_name` and run isolation

The first version of the override used the custom schema name as is for every target. That meant a CI run wrote to the same `STAGING` and `MARTS` schemas as prod, the schemas the dashboard reads. The problem was found during an audit.

The macro now branches on the target:

- no custom schema: use `target.schema`;
- `prod`: use the custom schema as is (`STAGING`, `MARTS`);
- any other target: prefix with `target.schema`, for example `dbt_ci_pr_12_marts`.

The CI workflow sets one schema per pull request (or run), and a `drop_ci_schemas` macro, restricted to the `ci` target, drops them afterwards. It matches on the `_` boundary so cleaning `dbt_ci_pr_1` cannot drop `dbt_ci_pr_12`.

## Calendar spine

Two models were fixed to use a real calendar:

- `dim_date` was built from the ship dates present in the data, which leaves gaps on days without activity. It now generates a spine from the first order date to the last ship date. `row_number()` over `seq4()` gives a gapless offset, because `seq4()` alone does not guarantee one. The generator emits a fixed 5000 days, clipped to the real max date, so `assert_dim_date_covers_facts` fails if the data ever outgrows it, and `assert_dim_date_contiguous` fails on any gap.
- `agg_margin_monthly` left joins monthly totals onto a month spine, so a month without sales shows zero instead of disappearing. This makes `lag(1)` and `lag(12)` true calendar shifts and the 3-month window cover three consecutive months. A first version flagged only calendar-partial months, which still left a visible collapse at the end of the trend chart. Querying the data showed the real cause: revenue is recognised on ship date, orders stop on 1998-08-02 and shipping lags orders by up to 121 days, so the first and last four months are ramp-up and run-off. `is_complete_month` now lives in `dim_date`, derived from those bounds, and the dashboard trend visuals filter on it. Percent changes use `nullif` and return NULL when the base is zero.

## Other notes

- `calculate_net_revenue` keeps the revenue definition in one macro instead of repeating it.
- Staging views hold no business logic; marts are tables because BI queries them repeatedly.
- `profiles.yml` stays outside the repository (`~/.dbt/`), apart from `ci/profiles.yml`, which reads every value from environment variables.
- Python 3.11 was needed for dbt on the original machine, installed side by side with `py -3.11`.
