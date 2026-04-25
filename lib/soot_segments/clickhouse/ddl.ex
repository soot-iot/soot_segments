defmodule SootSegments.ClickHouse.DDL do
  @moduledoc """
  Render the materialized-view + backing-table DDL for a segment.

  Two artifacts per segment version:

    1. The **target table** holds the partial aggregation states and is
       what queries `<Fn>Merge` against. It uses the
       `AggregatingMergeTree` engine.
    2. The **materialized view** reads from the source telemetry table
       and writes `<Fn>State` rows into the target.

  Tables are named `<target>_v<version>` (the registry stamps that into
  `materialized_target`); MVs are named `<target>_v<version>_mv`.

  Source-table conventions follow `soot_telemetry`'s default naming:
  `telemetry_<source_stream>`. Override via `:source_table` if your
  deployment differs.
  """

  alias SootSegments.ClickHouse.SQL
  alias SootSegments.Segment.Info

  @doc """
  Combined `CREATE TABLE` + `CREATE MATERIALIZED VIEW` for a single
  segment module. Targets the segment's *current* version target.
  """
  @spec create_view(module(), keyword()) :: String.t()
  def create_view(module, opts \\ []) do
    target = Keyword.get(opts, :target, default_target(module, opts))
    source_table = Keyword.get(opts, :source_table, default_source(module))
    db = Keyword.get(opts, :database)

    create_table(module, target, db) <>
      "\n\n" <>
      create_mv(module, target, source_table, db, opts)
  end

  @doc """
  Render the backfill `INSERT INTO … SELECT` statement.

  `from` is a `DateTime` (or any value rendered by `SQL.quote_value/1`)
  marking the lower bound of the source data the operator wants
  re-aggregated.
  """
  @spec backfill_sql(module(), DateTime.t() | nil, keyword()) :: String.t()
  def backfill_sql(module, from \\ nil, opts \\ []) do
    target = Keyword.get(opts, :target, default_target(module, opts))
    source_table = Keyword.get(opts, :source_table, default_source(module))
    db = Keyword.get(opts, :database)

    target_full = qualify(target, db)
    source_full = qualify(source_table, db)

    select_cols = select_state_cols(module)

    where = where_with_floor(module, from)

    """
    INSERT INTO #{target_full}
    SELECT
    #{select_cols}
    FROM #{source_full}
    #{where}
    GROUP BY #{group_by_cols(module)};\
    """
  end

  @doc "Render `CREATE TABLE` for the segment's target."
  @spec create_table(module(), String.t(), String.t() | nil) :: String.t()
  def create_table(module, target, db \\ nil) do
    target_full = qualify(target, db)
    bucket_col = bucket_column_def(module)
    dim_lines = dimension_columns(module)
    metric_lines = metric_state_columns(module)

    columns =
      [bucket_col | dim_lines ++ metric_lines]
      |> Enum.map(&("    " <> &1))
      |> Enum.join(",\n")

    order_by =
      ["bucket" | Enum.map(Info.dimensions(module), &Atom.to_string(&1.name))]
      |> Enum.join(", ")

    base = """
    CREATE TABLE IF NOT EXISTS #{target_full} (
    #{columns}
    )
    ENGINE = AggregatingMergeTree
    ORDER BY (#{order_by})\
    """

    base
    |> append_ttl(ttl_from_retention(Info.retention(module)))
    |> Kernel.<>(";")
  end

  @doc "Render `CREATE MATERIALIZED VIEW` for the segment."
  @spec create_mv(module(), String.t(), String.t(), String.t() | nil, keyword()) :: String.t()
  def create_mv(module, target, source_table, db \\ nil, _opts \\ []) do
    target_full = qualify(target, db)
    source_full = qualify(source_table, db)
    mv_name = mv_name(target)
    mv_full = qualify(mv_name, db)

    select_cols = select_state_cols(module)
    group_by = group_by_cols(module)
    where = SQL.where_clause(Info.filter(module), Info.raw_where(module))

    body = """
    CREATE MATERIALIZED VIEW IF NOT EXISTS #{mv_full}
    TO #{target_full}
    AS SELECT
    #{select_cols}
    FROM #{source_full}\
    """

    body =
      case where do
        "" -> body
        clause -> body <> "\n" <> clause
      end

    body <> "\nGROUP BY " <> group_by <> ";"
  end

  # ─── helpers ──────────────────────────────────────────────────────────

  defp default_target(module, opts) do
    Keyword.get_lazy(opts, :default_target, fn -> Info.target(module) <> "_v1" end)
  end

  defp default_source(module),
    do: "telemetry_" <> Atom.to_string(Info.source_stream(module))

  defp qualify(table, nil), do: table
  defp qualify(table, db), do: "#{db}.#{table}"

  defp mv_name(target), do: target <> "_mv"

  defp bucket_column_def(_module), do: "bucket DateTime"

  defp dimension_columns(module) do
    Info.dimensions(module)
    |> Enum.map(fn dim ->
      Atom.to_string(dim.name) <> " LowCardinality(String)"
    end)
  end

  defp metric_state_columns(module) do
    Info.metrics(module)
    |> Enum.map(fn metric ->
      Atom.to_string(metric.name) <> "_state " <> SQL.state_type(metric)
    end)
  end

  defp select_state_cols(module) do
    bucket_expr = "    #{SQL.bucket_fn(Info.granularity(module))}(ts) AS bucket"

    dim_exprs =
      Info.dimensions(module)
      |> Enum.map(fn d -> "    " <> Atom.to_string(d.name) end)

    metric_exprs =
      Info.metrics(module)
      |> Enum.map(fn m ->
        "    " <> SQL.state_expr(m) <> " AS " <> Atom.to_string(m.name) <> "_state"
      end)

    [bucket_expr | dim_exprs ++ metric_exprs]
    |> Enum.join(",\n")
  end

  defp group_by_cols(module) do
    ["bucket" | Enum.map(Info.dimensions(module), &Atom.to_string(&1.name))]
    |> Enum.join(", ")
  end

  defp where_with_floor(module, from) do
    floor_clause =
      case from do
        nil -> nil
        %DateTime{} = dt -> "ts >= " <> SQL.quote_value(DateTime.to_iso8601(dt))
        other -> "ts >= " <> SQL.quote_value(other)
      end

    eq_filter = SQL.where_clause(Info.filter(module), Info.raw_where(module))

    case {floor_clause, eq_filter} do
      {nil, ""} -> ""
      {nil, where} -> where
      {floor, ""} -> "WHERE " <> floor
      {floor, where} -> where <> " AND " <> floor
    end
  end

  defp append_ttl(sql, nil), do: sql
  defp append_ttl(sql, expr), do: sql <> "\nTTL " <> expr

  defp ttl_from_retention([]), do: nil

  defp ttl_from_retention(retention) when is_list(retention) do
    case retention do
      [{:days, n}] -> "bucket + INTERVAL #{n} DAY"
      [{:months, n}] -> "bucket + INTERVAL #{n} MONTH"
      [{:years, n}] -> "bucket + INTERVAL #{n} YEAR"
      _ -> nil
    end
  end
end
