defmodule SootSegments.Segment do
  @moduledoc """
  Spark DSL for declaring a segment (a slice × metrics × time).

      defmodule MyApp.Segments.VibrationP95 do
        use SootSegments.Segment.Definition

        segment do
          name :vibration_p95
          source_stream :vibration
          granularity :hour
          retention months: 24

          filter [tenant_id: "acme"]

          dimensions do
            dimension :tenant_id
            dimension :device_id
          end

          metrics do
            metric :axis_x_p95, :quantile, column: :axis_x, q: 0.95
            metric :axis_x_avg, :avg, column: :axis_x
            metric :samples, :count
          end
        end
      end

  Granularity → time-bucket function used in the MV `GROUP BY`:

      :minute → toStartOfMinute(ts)
      :five_minute → toStartOfFiveMinute(ts)
      :hour   → toStartOfHour(ts)
      :day    → toStartOfDay(ts)

  `filter` accepts a keyword list of column-value equality pairs. For
  more complex predicates, use `raw_where: "device_id LIKE 'TEMP-%'"` —
  the contents are inserted verbatim, so operators are responsible for
  trusting that input.
  """

  @granularities [:minute, :five_minute, :hour, :day]

  @dimension %Spark.Dsl.Entity{
    name: :dimension,
    target: SootSegments.Segment.Dimension,
    args: [:name],
    schema: [
      name: [type: :atom, required: true],
      as: [type: :atom, doc: "Column alias used in the GROUP BY output."]
    ]
  }

  @dimensions %Spark.Dsl.Section{
    name: :dimensions,
    describe: "Group-by columns for the segment.",
    entities: [@dimension]
  }

  @metric %Spark.Dsl.Entity{
    name: :metric,
    target: SootSegments.Segment.Metric,
    args: [:name, :aggregation],
    schema: [
      name: [type: :atom, required: true],
      aggregation: [
        type: {:one_of, SootSegments.Segment.Metric.aggregations()},
        required: true
      ],
      column: [
        type: :atom,
        doc: "Column to aggregate. Required for every aggregation except `:count`."
      ],
      q: [
        type: :float,
        doc: "Quantile in (0, 1); used only with aggregation: :quantile."
      ]
    ]
  }

  @metrics %Spark.Dsl.Section{
    name: :metrics,
    describe: "Aggregation expressions for the segment.",
    entities: [@metric]
  }

  @segment %Spark.Dsl.Section{
    name: :segment,
    describe: "Top-level segment declaration.",
    sections: [@dimensions, @metrics],
    schema: [
      name: [type: :atom, required: true, doc: "Segment identifier."],
      source_stream: [
        type: :atom,
        required: true,
        doc: "The telemetry stream this segment rolls up."
      ],
      granularity: [
        type: {:one_of, @granularities},
        default: :hour,
        doc: "Time-bucket granularity."
      ],
      retention: [
        type: :keyword_list,
        default: [],
        doc: "Optional retention hint, e.g. `[months: 24]`. Becomes a TTL on the target table."
      ],
      filter: [
        type: :keyword_list,
        default: [],
        doc: "Equality predicates as a keyword list, e.g. `[tenant_id: \"acme\", model: \"X\"]`."
      ],
      raw_where: [
        type: :string,
        doc:
          "Verbatim SQL predicate appended to the WHERE clause. Operator-trusted; not sanitised."
      ],
      target: [
        type: :string,
        doc: "Optional override for the materialized-view table name."
      ]
    ]
  }

  use Spark.Dsl.Extension, sections: [@segment]

  @doc "All granularities accepted by the DSL."
  @spec granularities() :: [atom()]
  def granularities, do: @granularities
end
