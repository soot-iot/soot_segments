defmodule SootSegments.ClickHouse.SQL do
  @moduledoc """
  Pure helpers shared between the MV compiler, the backfill SQL
  generator, and the query helpers.

  - Granularity → ClickHouse time-bucket function.
  - Aggregation → `<Fn>State` (for MV insertion) and `<Fn>Merge` (for
    SELECT) variants.
  - Filter keyword list + raw_where → `WHERE …` predicate.

  All functions are pure; no I/O.
  """

  @doc "ClickHouse time-bucket function for the given granularity."
  @spec bucket_fn(atom()) :: String.t()
  def bucket_fn(:minute), do: "toStartOfMinute"
  def bucket_fn(:five_minute), do: "toStartOfFiveMinute"
  def bucket_fn(:hour), do: "toStartOfHour"
  def bucket_fn(:day), do: "toStartOfDay"

  @doc """
  Render the `<Fn>State` expression used in the MV's SELECT (so that
  partial aggregation state is materialised, then merged at query time).
  """
  @spec state_expr(SootSegments.Segment.Metric.t()) :: String.t()
  def state_expr(%{aggregation: :count}), do: "countState()"
  def state_expr(%{aggregation: :sum, column: c}), do: "sumState(#{c})"
  def state_expr(%{aggregation: :avg, column: c}), do: "avgState(#{c})"
  def state_expr(%{aggregation: :min, column: c}), do: "minState(#{c})"
  def state_expr(%{aggregation: :max, column: c}), do: "maxState(#{c})"

  def state_expr(%{aggregation: :quantile, column: c, q: q}) when is_float(q) do
    "quantileTDigestState(#{q})(#{c})"
  end

  @doc """
  Render the `<Fn>Merge` expression used in queries that read the MV.
  Pairs with `state_expr/1`.
  """
  @spec merge_expr(SootSegments.Segment.Metric.t()) :: String.t()
  def merge_expr(%{aggregation: :count, name: n}),
    do: "countMerge(#{n}_state) AS #{n}"

  def merge_expr(%{aggregation: :sum, name: n}),
    do: "sumMerge(#{n}_state) AS #{n}"

  def merge_expr(%{aggregation: :avg, name: n}),
    do: "avgMerge(#{n}_state) AS #{n}"

  def merge_expr(%{aggregation: :min, name: n}),
    do: "minMerge(#{n}_state) AS #{n}"

  def merge_expr(%{aggregation: :max, name: n}),
    do: "maxMerge(#{n}_state) AS #{n}"

  def merge_expr(%{aggregation: :quantile, name: n, q: q}) do
    "quantileTDigestMerge(#{q})(#{n}_state) AS #{n}"
  end

  @doc """
  ClickHouse data type for the *State* column in the MV table. Used by
  the table schema generator.

  In v0.1 every metric uses the canonical state types pulled directly
  from ClickHouse — no operator-specified type overrides yet.
  """
  @spec state_type(SootSegments.Segment.Metric.t()) :: String.t()
  def state_type(%{aggregation: :count}), do: "AggregateFunction(count)"

  def state_type(%{aggregation: :sum, column: _}),
    do: "AggregateFunction(sum, Float64)"

  def state_type(%{aggregation: :avg, column: _}),
    do: "AggregateFunction(avg, Float64)"

  def state_type(%{aggregation: :min, column: _}),
    do: "AggregateFunction(min, Float64)"

  def state_type(%{aggregation: :max, column: _}),
    do: "AggregateFunction(max, Float64)"

  def state_type(%{aggregation: :quantile, q: q}) when is_float(q),
    do: "AggregateFunction(quantileTDigest(#{q}), Float64)"

  @doc """
  Render the WHERE predicate from a keyword list of equality pairs and
  an optional raw clause. Returns an empty string when both are blank.
  """
  @spec where_clause(keyword(), String.t() | nil) :: String.t()
  def where_clause(filter, raw_where) do
    eq = Enum.map(filter, fn {col, value} -> "#{col} = #{quote_value(value)}" end)

    parts = eq ++ if(raw_where in [nil, ""], do: [], else: ["(#{raw_where})"])

    case parts do
      [] -> ""
      _ -> "WHERE " <> Enum.join(parts, " AND ")
    end
  end

  @doc "Quote a value for inclusion in SQL. Strings are single-quoted with `'` doubled."
  @spec quote_value(term()) :: String.t()
  def quote_value(value) when is_binary(value) do
    "'" <> String.replace(value, "'", "''") <> "'"
  end

  def quote_value(value) when is_integer(value) or is_float(value), do: to_string(value)
  def quote_value(true), do: "1"
  def quote_value(false), do: "0"
  def quote_value(value) when is_atom(value), do: quote_value(Atom.to_string(value))
end
