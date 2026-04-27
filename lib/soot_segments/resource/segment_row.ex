defmodule SootSegments.Resource.SegmentRow do
  @moduledoc """
  `Ash.Resource` extension that injects the `SootSegments` segment-row
  schema into a consumer-owned resource module.

  Usage and override semantics mirror `SootCore.Resource.Tenant`. Register
  via `config :soot_segments, segment_row: MyApp.SegmentRow`.
  """

  use Spark.Dsl.Extension,
    transformers: [SootSegments.Resource.SegmentRow.Transformers.Inject]
end
