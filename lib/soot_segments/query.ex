defmodule SootSegments.Query do
  @moduledoc """
  Compose SQL against a segment's current materialized view.

      SootSegments.Query.sql(MyApp.Segments.VibrationP95,
        from: ~U[2026-04-25 00:00:00Z],
        until: ~U[2026-04-26 00:00:00Z],
        dims: [:device_id]
      )

  Returns the raw SQL string. Running it is the operator's job (via the
  `:ch` driver, the EMQX SQL bridge, ClickHouse HTTP, etc.).

  The MV target is resolved by reading the segment's registered
  `SegmentRow.target`. Callers must register the module first
  (`SootSegments.Registry.register/1`); pass `target:` explicitly to
  query a specific historical version.

  `cinder/2` returns a structure suitable for handing to a Cinder
  table. The shape is intentionally framework-agnostic: a map with
  `:sql`, `:params`, `:columns` keys; the operator's Cinder helper
  consumes it.
  """

  alias SootSegments.ClickHouse.SQL
  alias SootSegments.Segment.Info

  @default_window_hours 24

  @doc """
  Render a SELECT against the segment's MV.

  Options:
    * `:from`, `:until` — `DateTime` window. Defaults to the last 24h
      ending now.
    * `:dims` — subset of dimensions to include. Defaults to all.
    * `:metrics` — subset of metric names. Defaults to all.
    * `:target` — override the MV target. Defaults to
      `<segment>_v<latest>` based on the registered segment row.
  """
  @spec sql(module(), keyword()) :: String.t()
  def sql(module, opts \\ []) do
    {from, until} = window(opts)

    target = Keyword.get(opts, :target, default_target(module))
    dims = resolve_dimensions(module, opts)
    metrics = resolve_metrics(module, opts)

    select_lines =
      ["    bucket"] ++
        Enum.map(dims, fn d -> "    " <> Atom.to_string(d.name) end) ++
        Enum.map(metrics, fn m -> "    " <> SQL.merge_expr(m) end)

    group_lines =
      ["bucket" | Enum.map(dims, &Atom.to_string(&1.name))]
      |> Enum.join(", ")

    """
    SELECT
    #{Enum.join(select_lines, ",\n")}
    FROM #{target}
    WHERE bucket >= #{SQL.quote_value(DateTime.to_iso8601(from))}
      AND bucket <  #{SQL.quote_value(DateTime.to_iso8601(until))}
    GROUP BY #{group_lines}
    ORDER BY bucket ASC;\
    """
  end

  @doc """
  Cinder-friendly result spec: `{sql, columns}` for an operator-side
  helper that runs the query and binds the columns to a Cinder table.

      %{
        sql: "...",
        columns: [
          %{name: :bucket, type: :datetime},
          %{name: :device_id, type: :string},
          %{name: :axis_x_p95, type: :float}
        ]
      }
  """
  @spec cinder(module(), keyword()) :: map()
  def cinder(module, opts \\ []) do
    %{
      sql: sql(module, opts),
      columns: cinder_columns(module, opts)
    }
  end

  defp cinder_columns(module, opts) do
    dims = resolve_dimensions(module, opts)
    metrics = resolve_metrics(module, opts)

    [%{name: :bucket, type: :datetime}] ++
      Enum.map(dims, &%{name: &1.name, type: :string}) ++
      Enum.map(metrics, &%{name: &1.name, type: metric_value_type(&1)})
  end

  defp metric_value_type(%{aggregation: :count}), do: :integer
  defp metric_value_type(_), do: :float

  defp resolve_dimensions(module, opts) do
    case Keyword.get(opts, :dims) do
      nil ->
        Info.dimensions(module)

      list ->
        wanted = MapSet.new(list)
        Enum.filter(Info.dimensions(module), &MapSet.member?(wanted, &1.name))
    end
  end

  defp resolve_metrics(module, opts) do
    case Keyword.get(opts, :metrics) do
      nil ->
        Info.metrics(module)

      list ->
        wanted = MapSet.new(list)
        Enum.filter(Info.metrics(module), &MapSet.member?(wanted, &1.name))
    end
  end

  defp window(opts) do
    until = Keyword.get(opts, :until, DateTime.utc_now())

    from =
      case Keyword.get(opts, :from) do
        nil -> DateTime.add(until, -@default_window_hours * 3_600, :second)
        value -> value
      end

    {from, until}
  end

  defp default_target(module) do
    name = Info.name(module)

    case SootSegments.segment_row().get_by_name(name, authorize?: false) do
      {:ok, %{target: target}} when is_binary(target) ->
        target

      _ ->
        raise ArgumentError,
              "segment #{inspect(name)} (#{inspect(module)}) is not registered; " <>
                "call SootSegments.Registry.register/1 first or pass `target:` explicitly"
    end
  end
end
