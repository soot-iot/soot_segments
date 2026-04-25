defmodule SootSegments do
  @moduledoc """
  Segments: rollups over telemetry streams.

  A segment names a slice of the fleet × metrics × time. Compiles to
  ClickHouse materialized views; each definition change makes a new
  version with a date floor (no automatic backfill — operators run
  `Segment.backfill/3` explicitly when they want history rebuilt).

  See `SootSegments.Segment` for the DSL and
  `SootSegments.ClickHouse.DDL` for the materialized-view renderer.
  """
end
