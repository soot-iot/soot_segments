defmodule SootSegments.Fingerprint do
  @moduledoc """
  Fingerprint a segment definition into a stable hex SHA-256 of the
  canonical JSON descriptor. Mirrors `SootTelemetry.Schema.Fingerprint`.
  """

  alias SootSegments.Segment.{Dimension, Info, Metric}

  @doc "Canonical, JSON-serialisable description of the segment."
  @spec descriptor(module()) :: map()
  def descriptor(module) do
    %{
      name: Info.name(module),
      source_stream: Info.source_stream(module),
      granularity: Info.granularity(module),
      retention: Map.new(Info.retention(module)),
      filter: Map.new(Info.filter(module)),
      raw_where: Info.raw_where(module),
      target: Info.target(module),
      dimensions: Enum.map(Info.dimensions(module), &dim_descriptor/1),
      metrics: Enum.map(Info.metrics(module), &metric_descriptor/1)
    }
  end

  @doc "Hex SHA-256 of the canonical descriptor."
  @spec compute(module()) :: String.t()
  def compute(module) do
    descriptor(module)
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "Same hash starting from a stored descriptor map."
  @spec compute_descriptor(map()) :: String.t()
  def compute_descriptor(descriptor) when is_map(descriptor) do
    descriptor
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp dim_descriptor(%Dimension{name: name, as: a}), do: %{name: name, as: a}

  defp metric_descriptor(%Metric{} = m) do
    %{name: m.name, aggregation: m.aggregation, column: m.column, q: m.q}
  end

  defp canonical_json(value) do
    value
    |> sort_keys()
    |> Jason.encode!()
  end

  defp sort_keys(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {to_string(k), sort_keys(v)} end)
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Jason.OrderedObject.new()
  end

  defp sort_keys(value) when is_list(value), do: Enum.map(value, &sort_keys/1)
  defp sort_keys(value), do: value
end
