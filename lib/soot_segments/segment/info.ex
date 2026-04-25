defmodule SootSegments.Segment.Info do
  @moduledoc """
  Introspection for `segment do … end`.

      SootSegments.Segment.Info.name(MyApp.Segments.VibrationP95)
      SootSegments.Segment.Info.dimensions(MyApp.Segments.VibrationP95)
      SootSegments.Segment.Info.metrics(MyApp.Segments.VibrationP95)
  """

  use Spark.InfoGenerator,
    extension: SootSegments.Segment,
    sections: [:segment]

  alias SootSegments.Segment.{Dimension, Metric}

  @doc "All dimension entities in declaration order."
  @spec dimensions(module()) :: [Dimension.t()]
  def dimensions(module),
    do: Spark.Dsl.Extension.get_entities(module, [:segment, :dimensions])

  @doc "All metric entities in declaration order."
  @spec metrics(module()) :: [Metric.t()]
  def metrics(module), do: Spark.Dsl.Extension.get_entities(module, [:segment, :metrics])

  @doc "Convenience: stream name from `source_stream`."
  @spec source_stream(module()) :: atom()
  def source_stream(module), do: segment_source_stream!(module)

  @doc "Convenience: bucket granularity."
  @spec granularity(module()) :: atom()
  def granularity(module), do: segment_granularity!(module)

  @doc "Convenience: filter keyword list."
  @spec filter(module()) :: keyword()
  def filter(module), do: segment_filter!(module)

  @doc "Convenience: optional raw WHERE clause."
  @spec raw_where(module()) :: String.t() | nil
  def raw_where(module),
    do: Spark.Dsl.Extension.get_opt(module, [:segment], :raw_where, nil)

  @doc "Convenience: retention keyword list."
  @spec retention(module()) :: keyword()
  def retention(module), do: segment_retention!(module)

  @doc "Convenience: segment name."
  @spec name(module()) :: atom()
  def name(module), do: segment_name!(module)

  @doc "Effective MV target table name (operator override or `segment_<name>`)."
  @spec target(module()) :: String.t()
  def target(module) do
    case Spark.Dsl.Extension.get_opt(module, [:segment], :target, nil) do
      nil -> "segment_" <> Atom.to_string(name(module))
      override -> override
    end
  end
end
