defmodule SootSegments.SegmentVersion do
  @moduledoc """
  Default `SegmentVersion` resource shipped with `soot_segments`.

  A historical version of a segment definition.

  Each definition fingerprint produces one row. The current row for a
  segment is referenced by `SegmentRow.current_version_id`. Old rows
  remain `:deprecated` until explicitly `:retired` so historical data
  served from old materialized views isn't silently invalidated.

  `date_floor` is the timestamp at which a new version begins
  collecting data. It defaults to `now()` at creation time so backfills
  are explicit (operator runs `Segment.backfill/3`).

  The schema is provided by the `SootSegments.Resource.SegmentVersion`
  extension. This default uses `Ash.DataLayer.Ets`; production
  deployments override with their own resource module backed by
  `AshPostgres.DataLayer` and register it via
  `config :soot_segments, segment_version: MyApp.SegmentVersion`.
  """

  use Ash.Resource,
    otp_app: :soot_segments,
    domain: SootSegments.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [SootSegments.Resource.SegmentVersion]

  ets do
    private? false
  end

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
