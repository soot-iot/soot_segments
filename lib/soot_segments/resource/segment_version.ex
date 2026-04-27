defmodule SootSegments.Resource.SegmentVersion do
  @moduledoc """
  `Ash.Resource` extension that injects the `SootSegments` segment-version
  schema into a consumer-owned resource module.

  Usage and override semantics mirror `SootCore.Resource.Tenant`. Register
  via `config :soot_segments, segment_version: MyApp.SegmentVersion`.
  """

  use Spark.Dsl.Extension,
    transformers: [SootSegments.Resource.SegmentVersion.Transformers.Inject]
end
