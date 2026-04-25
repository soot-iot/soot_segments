defmodule SootSegments.SegmentDslTest do
  use ExUnit.Case, async: true

  alias SootSegments.Segment.Info
  alias SootSegments.Test.Fixtures.{PowerDaily, VibrationP95}

  describe "section options" do
    test "name, source_stream, granularity, retention" do
      assert Info.name(VibrationP95) == :vibration_p95
      assert Info.source_stream(VibrationP95) == :vibration
      assert Info.granularity(VibrationP95) == :hour
      assert Info.retention(VibrationP95) == [months: 24]
    end

    test "filter is a keyword list" do
      assert Info.filter(VibrationP95) == [tenant_id: "acme"]
      assert Info.filter(PowerDaily) == []
    end

    test "target defaults to segment_<name>" do
      assert Info.target(VibrationP95) == "segment_vibration_p95"
    end

    test "raw_where is nil when unset" do
      assert is_nil(Info.raw_where(VibrationP95))
    end
  end

  describe "dimensions and metrics" do
    test "preserves declaration order" do
      dims = VibrationP95 |> Info.dimensions() |> Enum.map(& &1.name)
      assert dims == [:tenant_id, :device_id]

      metrics = VibrationP95 |> Info.metrics() |> Enum.map(& &1.name)
      assert metrics == [:axis_x_p95, :axis_x_avg, :samples]
    end

    test "metric carries q for quantile" do
      [p95 | _] = Info.metrics(VibrationP95)
      assert p95.aggregation == :quantile
      assert p95.column == :axis_x
      assert p95.q == 0.95
    end

    test "count metric has nil column" do
      samples = Info.metrics(VibrationP95) |> Enum.find(&(&1.name == :samples))
      assert samples.column == nil
    end
  end

  describe "DSL parse-time validation" do
    test "rejects missing name" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule NoName do
          use SootSegments.Segment.Definition

          segment do
            source_stream :vibration

            dimensions do
              dimension :tenant_id
            end

            metrics do
              metric :s, :count
            end
          end
        end
      end
    end

    test "rejects unknown aggregation" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule BadAgg do
          use SootSegments.Segment.Definition

          segment do
            name :bad_agg
            source_stream :v

            dimensions do
              dimension :tenant_id
            end

            metrics do
              metric :x, :stddev_pop, column: :y
            end
          end
        end
      end
    end

    test "rejects unknown granularity" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule BadGran do
          use SootSegments.Segment.Definition

          segment do
            name :bad_gran
            source_stream :v
            granularity :nanosecond

            dimensions do
              dimension :tenant_id
            end

            metrics do
              metric :s, :count
            end
          end
        end
      end
    end
  end
end
