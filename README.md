# `soot_segments`

Segment definitions, ClickHouse materialized-view compiler, versioning,
and explicit-only backfill helpers.

Depends on [`ash_pki`](../ash_pki), [`soot_core`](../soot_core), and
[`soot_telemetry`](../soot_telemetry). Like the rest of the framework,
`soot_segments` does not depend on a ClickHouse client; it stops at
producing SQL artifacts.

## DSL

```elixir
defmodule MyApp.Segments.VibrationP95 do
  use SootSegments.Segment.Definition

  segment do
    name :vibration_p95
    source_stream :vibration
    granularity :hour
    retention months: 24

    filter [tenant_id: "acme"]

    dimensions do
      dimension :tenant_id
      dimension :device_id
    end

    metrics do
      metric :axis_x_p95, :quantile, column: :axis_x, q: 0.95
      metric :axis_x_avg, :avg, column: :axis_x
      metric :samples, :count
    end
  end
end
```

`granularity` ∈ `:minute | :five_minute | :hour | :day`, mapped to
`toStartOfMinute` / `toStartOfFiveMinute` / `toStartOfHour` /
`toStartOfDay` respectively.

`filter` is a keyword list of equality predicates. For more complex
predicates, use `raw_where: "..."` — the contents are inserted verbatim,
so operators are responsible for trusting the input.

## Aggregations

| name        | uses on insert            | uses on read                    | result type |
|-------------|---------------------------|---------------------------------|-------------|
| `:count`    | `countState()`            | `countMerge(<m>_state)`         | integer     |
| `:sum`      | `sumState(c)`             | `sumMerge(<m>_state)`           | float       |
| `:avg`      | `avgState(c)`             | `avgMerge(<m>_state)`           | float       |
| `:min`      | `minState(c)`             | `minMerge(<m>_state)`           | float       |
| `:max`      | `maxState(c)`             | `maxMerge(<m>_state)`           | float       |
| `:quantile` | `quantileTDigestState(q)(c)` | `quantileTDigestMerge(q)(<m>_state)` | float |

The MV writes `<Fn>State` rows into an `AggregatingMergeTree` target;
queries `<Fn>Merge` to get the value. The state-column on the target is
named `<metric>_state`; the merged value comes back as `<metric>`.

## Versioning

`SootSegments.Registry.register/1` upserts:

- `SootSegments.SegmentRow` — one per registered segment, points at
  `current_version_id`.
- `SootSegments.SegmentVersion` — one per fingerprint. Each fingerprint
  change creates a new version with `status: :current` and
  `date_floor: now()`; the previous current version moves to
  `:deprecated`. Old MV tables are NOT dropped automatically.

`materialized_target` is `<segment>_v<version>` so old and new
materialized views can coexist.

## Compiling to ClickHouse

`SootSegments.ClickHouse.DDL.create_view/2` returns a CREATE TABLE
(`AggregatingMergeTree`) plus a `CREATE MATERIALIZED VIEW … TO …`. The
MV reads from `telemetry_<source_stream>` (the default
`soot_telemetry` table name; override with `:source_table`).

`backfill_sql/3` returns the explicit `INSERT INTO target SELECT …`
statement to re-aggregate historical data. Backfill is **never**
implicit on a definition change.

## Querying

`SootSegments.Query.sql/2` composes a SELECT against the MV with merge
semantics applied per metric:

```elixir
SootSegments.Query.sql(MyApp.Segments.VibrationP95,
  from: ~U[2026-04-25 00:00:00Z],
  until: ~U[2026-04-26 00:00:00Z],
  dims: [:device_id],
  metrics: [:axis_x_p95, :samples]
)
```

`SootSegments.Query.cinder/2` wraps it as `%{sql: ..., columns:
[%{name:, type:}, ...]}` for direct consumption by an operator's Cinder
helper. Column types: `:bucket → :datetime`, dimensions → `:string`,
`:count → :integer`, everything else → `:float`.

## Mix tasks

```sh
mix soot_segments.gen_migrations \
      --out priv/migrations/V0010__segments.sql \
      --segment MyApp.Segments.VibrationP95 \
      [--database iot]

mix soot_segments.gen_backfill \
      --out priv/migrations/V0011__backfill_vibration_p95.sql \
      --segment MyApp.Segments.VibrationP95 \
      --from 2026-01-01T00:00:00Z
```

## Out of scope (v0.1)

* ClickHouse client and migration runner. The mix tasks emit SQL
  files; operators apply them with their tooling of choice.
* Cross-segment joins.
* Ad-hoc segment creation via UI.
* Segment definitions over non-telemetry resources.
* Compiling Ash filter expressions over `soot_core.Device` to ClickHouse
  predicates. The `:filter` field accepts a keyword list and a
  `:raw_where` escape hatch in v0.1; the Ash-filter compiler is a
  follow-up.

## Tests

```sh
mix test
```

Covers: DSL parsing + parse-time rejections (missing name, unknown
aggregation, unknown granularity), fingerprint determinism +
key-order independence + sensitivity to metric/filter changes, the
registry's idempotence + version bump + deprecated-reuse promotion +
concurrent-register recovery, every `state_expr` / `merge_expr` /
`state_type` for every aggregation, where-clause construction with
quoting + raw escape hatch, full table + MV + backfill DDL across
both fixture segments, registry-aware query SQL with
`from/until/dims/metrics/target` overrides, the cinder shape with
column typing, and both mix tasks end-to-end with file output
assertions.
