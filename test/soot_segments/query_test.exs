defmodule SootSegments.QueryTest do
  use ExUnit.Case, async: false

  alias SootSegments.{Query, Registry}
  alias SootSegments.Test.Factories
  alias SootSegments.Test.Fixtures.{PowerDaily, VibrationP95}

  setup do
    Factories.reset!()
    {:ok, _} = Registry.register(VibrationP95)
    {:ok, _} = Registry.register(PowerDaily)
    :ok
  end

  describe "sql/2" do
    test "produces a SELECT against the registered segment's current MV target" do
      sql = Query.sql(VibrationP95)
      assert sql =~ "FROM segment_vibration_p95_v1"
    end

    test "raises when the segment has not been registered" do
      Factories.reset!()

      assert_raise ArgumentError, ~r/not registered/, fn ->
        Query.sql(VibrationP95)
      end
    end

    test "merges every metric with its <Fn>Merge variant" do
      sql = Query.sql(VibrationP95)
      assert sql =~ "quantileTDigestMerge(0.95)(axis_x_p95_state) AS axis_x_p95"
      assert sql =~ "avgMerge(axis_x_avg_state) AS axis_x_avg"
      assert sql =~ "countMerge(samples_state) AS samples"
    end

    test "honours --dims subset" do
      sql = Query.sql(VibrationP95, dims: [:device_id])
      assert sql =~ "GROUP BY bucket, device_id"
      refute sql =~ "GROUP BY bucket, tenant_id"
    end

    test "honours --metrics subset" do
      sql = Query.sql(VibrationP95, metrics: [:samples])
      assert sql =~ "countMerge(samples_state) AS samples"
      refute sql =~ "axis_x_p95"
    end

    test "honours --target override" do
      sql = Query.sql(VibrationP95, target: "segment_vibration_p95_v3")
      assert sql =~ "FROM segment_vibration_p95_v3"
    end

    test "default window is the last 24 hours ending now" do
      sql = Query.sql(VibrationP95)
      assert sql =~ "WHERE bucket >= "
      assert sql =~ "AND bucket <"
    end

    test "explicit from/until are quoted" do
      sql =
        Query.sql(VibrationP95,
          from: ~U[2026-04-25 00:00:00Z],
          until: ~U[2026-04-26 00:00:00Z]
        )

      assert sql =~ "WHERE bucket >= '2026-04-25T00:00:00Z'"
      assert sql =~ "AND bucket <  '2026-04-26T00:00:00Z'"
    end
  end

  describe "cinder/2" do
    test "wraps sql + columns" do
      result = Query.cinder(VibrationP95)
      assert is_binary(result.sql)
      assert is_list(result.columns)
    end

    test "every dimension and metric becomes a column with a type" do
      %{columns: cols} = Query.cinder(VibrationP95)
      names = Enum.map(cols, & &1.name)

      assert :bucket in names
      assert :tenant_id in names
      assert :device_id in names
      assert :axis_x_p95 in names
      assert :samples in names
    end

    test "count metric → :integer, others → :float" do
      %{columns: cols} = Query.cinder(VibrationP95)
      types = Map.new(cols, fn %{name: n, type: t} -> {n, t} end)

      assert types[:samples] == :integer
      assert types[:axis_x_p95] == :float
      assert types[:bucket] == :datetime
    end

    test "respects dims/metrics subsetting" do
      %{columns: cols} = Query.cinder(PowerDaily, dims: [:device_id], metrics: [:watts_avg])
      names = Enum.map(cols, & &1.name)

      assert names == [:bucket, :device_id, :watts_avg]
    end
  end
end
