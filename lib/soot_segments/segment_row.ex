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
    authorizers: [Ash.Policy.Authorizer],
    extensions: [SootSegments.Resource.SegmentRow]

  ets do
    private? false
  end

  # Default policies (POLICY-SPEC §4.1). Library-internal flows run
  # as `SootSegments.Actors.system(:registry_sync)`. Operators
  # override this resource and widen the allow list for their User
  # actors.
  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if always()
    end

    policy always() do
      access_type :strict
      authorize_if actor_attribute_equals(:part, :registry_sync)
    end
  end
end
