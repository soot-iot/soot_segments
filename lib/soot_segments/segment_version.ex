defmodule SootSegments.SegmentVersion do
  @moduledoc """
  A historical version of a segment definition.

  Each definition fingerprint produces one row. The current row for a
  segment is referenced by `SegmentRow.current_version_id`. Old rows
  remain `:deprecated` until explicitly `:retired` so historical data
  served from old materialized views isn't silently invalidated.

  `date_floor` is the timestamp at which a new version begins
  collecting data. It defaults to `now()` at creation time so backfills
  are explicit (operator runs `Segment.backfill/3`).
  """

  use Ash.Resource,
    otp_app: :soot_segments,
    domain: SootSegments.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id

    attribute :segment_name, :atom, allow_nil?: false, public?: true
    attribute :version, :integer, allow_nil?: false, public?: true
    attribute :fingerprint, :string, allow_nil?: false, public?: true
    attribute :definition, :map, allow_nil?: false, public?: true
    attribute :date_floor, :utc_datetime_usec, allow_nil?: false, public?: true

    attribute :status, :atom do
      constraints one_of: [:current, :deprecated, :retired]
      default :current
      allow_nil? false
      public? true
    end

    attribute :materialized_target, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_fingerprint_per_segment, [:segment_name, :fingerprint],
      pre_check_with: SootSegments.Domain

    identity :unique_version_per_segment, [:segment_name, :version],
      pre_check_with: SootSegments.Domain
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :segment_name,
        :version,
        :fingerprint,
        :definition,
        :date_floor,
        :materialized_target
      ]
    ]

    update :deprecate do
      accept []
      require_atomic? false
      change set_attribute(:status, :deprecated)
    end

    update :retire do
      accept []
      require_atomic? false
      change set_attribute(:status, :retired)
    end

    read :for_segment do
      argument :segment_name, :atom, allow_nil?: false
      filter expr(segment_name == ^arg(:segment_name))
      prepare build(sort: [version: :desc])
    end

    read :get_by_fingerprint do
      argument :segment_name, :atom, allow_nil?: false
      argument :fingerprint, :string, allow_nil?: false
      get? true
      filter expr(segment_name == ^arg(:segment_name) and fingerprint == ^arg(:fingerprint))
    end
  end

  code_interface do
    define :create,
      args: [:segment_name, :version, :fingerprint, :definition, :date_floor]

    define :deprecate
    define :retire
    define :for_segment, args: [:segment_name]
    define :get_by_fingerprint, args: [:segment_name, :fingerprint]
  end
end
