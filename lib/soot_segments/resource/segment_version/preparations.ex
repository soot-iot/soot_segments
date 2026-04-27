defmodule SootSegments.Resource.SegmentVersion.Preparations do
  @moduledoc false

  defmodule ForSegment do
    @moduledoc false
    use Ash.Resource.Preparation
    require Ash.Query

    @impl true
    def prepare(query, _opts, _context) do
      segment_name = Ash.Query.get_argument(query, :segment_name)

      query
      |> Ash.Query.filter(segment_name == ^segment_name)
      |> Ash.Query.sort(version: :desc)
    end
  end

  defmodule GetByFingerprint do
    @moduledoc false
    use Ash.Resource.Preparation
    require Ash.Query

    @impl true
    def prepare(query, _opts, _context) do
      segment_name = Ash.Query.get_argument(query, :segment_name)
      fingerprint = Ash.Query.get_argument(query, :fingerprint)
      Ash.Query.filter(query, segment_name == ^segment_name and fingerprint == ^fingerprint)
    end
  end
end
