defmodule SootSegments.SegmentRow do
  @moduledoc """
  A registered segment.

  Named `SegmentRow` to avoid colliding with the Spark DSL extension
  `SootSegments.Segment` users put on their own modules.
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

    attribute :name, :atom, allow_nil?: false, public?: true
    attribute :module, :atom, public?: true
    attribute :source_stream, :atom, allow_nil?: false, public?: true
    attribute :granularity, :atom, allow_nil?: false, public?: true
    attribute :current_version_id, :uuid, allow_nil?: false, public?: true

    attribute :status, :atom do
      constraints one_of: [:active, :paused, :retired]
      default :active
      allow_nil? false
      public? true
    end

    attribute :target, :string, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_name, [:name], pre_check_with: SootSegments.Domain
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:name, :module, :source_stream, :granularity, :current_version_id, :target],
      update: [:current_version_id, :target]
    ]

    update :pause do
      accept []
      require_atomic? false
      change set_attribute(:status, :paused)
    end

    update :resume do
      accept []
      require_atomic? false
      change set_attribute(:status, :active)
    end

    update :retire do
      accept []
      require_atomic? false
      change set_attribute(:status, :retired)
    end

    read :get_by_name do
      argument :name, :atom, allow_nil?: false
      get? true
      filter expr(name == ^arg(:name))
    end
  end

  code_interface do
    define :create, args: [:name, :module, :source_stream, :granularity, :current_version_id]
    define :pause
    define :resume
    define :retire
    define :get_by_name, args: [:name]
  end
end
