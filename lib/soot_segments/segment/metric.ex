defmodule SootSegments.Segment.Metric do
  @moduledoc """
  A rollup metric: an aggregation function over a column.

  `aggregation` is the SQL-side function. For `:quantile`, supply `q`
  (e.g. `q: 0.95`).

  At MV insert time the renderer uses the `<Fn>State` variant
  (`avgState`, `quantileTDigestState`, …) so partial state can be
  combined; queries `SELECT … <fn>Merge(state)`.
  """

  @aggregations [:count, :sum, :avg, :min, :max, :quantile]

  defstruct [
    :name,
    :aggregation,
    :column,
    :q,
    __spark_metadata__: nil
  ]

  @type aggregation :: unquote(Enum.reduce(@aggregations, &{:|, [], [&1, &2]}))

  @type t :: %__MODULE__{
          name: atom(),
          aggregation: aggregation(),
          column: atom() | nil,
          q: float() | nil
        }

  @doc "Every aggregation accepted by the DSL."
  @spec aggregations() :: [atom()]
  def aggregations, do: @aggregations
end
