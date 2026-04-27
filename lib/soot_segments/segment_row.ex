defmodule SootSegments.SegmentRow do
  @moduledoc """
  Default `SegmentRow` resource shipped with `soot_segments`.

  A registered segment.

  Named `SegmentRow` to avoid colliding with the Spark DSL extension
  `SootSegments.Segment` users put on their own modules.

  The schema is provided by the `SootSegments.Resource.SegmentRow`
  extension. This default uses `Ash.DataLayer.Ets`; production
  deployments override with their own resource module backed by
  `AshPostgres.DataLayer` and register it via
  `config :soot_segments, segment_row: MyApp.SegmentRow`.
  """

  use Ash.Resource,
    otp_app: :soot_segments,
    domain: SootSegments.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [SootSegments.Resource.SegmentRow]

  ets do
    private? false
  end
end
