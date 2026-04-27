defmodule SootSegments do
  @moduledoc """
  Segments: rollups over telemetry streams.

  A segment names a slice of the fleet × metrics × time. Compiles to
  ClickHouse materialized views; each definition change makes a new
  version with a date floor (no automatic backfill — operators run
  `Segment.backfill/3` explicitly when they want history rebuilt).

  See `SootSegments.Segment` for the DSL and
  `SootSegments.ClickHouse.DDL` for the materialized-view renderer.

  ## Resource overrides

  Each resource ships as an `Ash.Resource` extension under
  `SootSegments.Resource.*` plus a thin `Ash.DataLayer.Ets` default
  under `SootSegments.*`. Production deployments override with their
  own AshPostgres-backed modules:

      config :soot_segments,
        segment_row: MyApp.SegmentRow,
        segment_version: MyApp.SegmentVersion
  """

  @doc "Configured `SegmentRow` resource module."
  @spec segment_row() :: module()
  def segment_row,
    do: Application.get_env(:soot_segments, :segment_row, SootSegments.SegmentRow)

  @doc "Configured `SegmentVersion` resource module."
  @spec segment_version() :: module()
  def segment_version,
    do: Application.get_env(:soot_segments, :segment_version, SootSegments.SegmentVersion)
end
