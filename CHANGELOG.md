# Changelog

All notable changes to `soot_segments` are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project adheres to semantic versioning.

## [Unreleased]

### Added
- `mix soot_segments.install` now generates AshPostgres-backed
  consumer `SegmentRow` and `SegmentVersion` resource modules under
  `lib/<app>/segment_row.ex` and `lib/<app>/segment_version.ex` and
  registers them in `config/config.exs` under
  `:soot_segments, segment_row:` / `:soot_segments, segment_version:`.
  The installer composes `ash_postgres.install` to wire the
  consumer's Repo and the `:ash_postgres` dep. The library's own
  concrete defaults stay on `Ash.DataLayer.Ets` for the soot_segments
  test suite; consumer projects always boot against AshPostgres,
  which is mandatory in the soot stack.
- `SegmentVersion :promote` action: transitions a `:deprecated` row
  back to `:current`. Used by the registry when an operator
  re-registers an older fingerprint.
- `HeartbeatFiveMinute` test fixture covering `:five_minute`
  granularity end-to-end through the DDL renderer.

### Changed
- `SootSegments.Query.sql/2` now reads the current `materialized_target`
  from the registered `SegmentRow` instead of always rendering `_v1`.
  Raises `ArgumentError` if the segment hasn't been registered; pass
  `target:` explicitly to query a specific historical version.
- `mix soot_segments.gen_migrations` and `mix soot_segments.gen_backfill`
  register their `--segment` modules first and emit DDL/backfill SQL
  for the *current* version's target table, so a definition change
  produces v2 DDL on the next run.
- `Registry.register/1` for a re-encountered `:deprecated` fingerprint
  now demotes the prior current version and promotes the matched row
  back to `:current` (rollback path). Re-registering a `:retired`
  fingerprint returns `{:error, :cannot_reuse_retired_version}`.
- `Registry.register/1` recovers from concurrent-register identity
  violations by re-looking-up the freshly-created row instead of
  surfacing the raw `{:error, _}`.
- `SQL.merge_expr/2` is now `merge_expr/1` (the second argument was
  always `nil`).
- `SQL.quote_value(nil)` raises `ArgumentError` with a hint about
  `IS NULL` instead of silently rendering `'nil'`.

### Removed
- `Dimension :as` field — declared but never rendered, and
  contributed to the fingerprint, forcing spurious version bumps.
- `SegmentRow.module` attribute — set on first register and never
  read.
- Empty `SootSegments.Application` supervisor.

## [0.1.0] - 2026-04-26

### Added
- Initial Phase 5 release: `SootSegments.Segment` Spark DSL,
  `SegmentRow`/`SegmentVersion` Ash resources, fingerprinting,
  registry with idempotent versioning and `date_floor`,
  `AggregatingMergeTree` MV/backfill DDL compiler with `<Fn>State` /
  `<Fn>Merge` semantics, query helpers (incl. cinder shape), and the
  `mix soot_segments.gen_migrations` + `mix soot_segments.gen_backfill`
  tasks. Backfill is explicit-only.
