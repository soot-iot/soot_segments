defmodule SootSegments.ClickHouse.DDLTest do
  use ExUnit.Case, async: true

  alias SootSegments.ClickHouse.DDL
  alias SootSegments.Test.Fixtures.{PowerDaily, VibrationP95}

  describe "create_table/3" do
    test "renders bucket + dimensions + state columns + AggregatingMergeTree" do
      sql = DDL.create_table(VibrationP95, "segment_vibration_p95_v1")

      assert sql =~ "CREATE TABLE IF NOT EXISTS segment_vibration_p95_v1"
      assert sql =~ "bucket DateTime"
      assert sql =~ "tenant_id LowCardinality(String)"
      assert sql =~ "device_id LowCardinality(String)"
      assert sql =~ "axis_x_p95_state AggregateFunction(quantileTDigest(0.95), Float64)"
      assert sql =~ "axis_x_avg_state AggregateFunction(avg, Float64)"
      assert sql =~ "samples_state AggregateFunction(count)"
      assert sql =~ "ENGINE = AggregatingMergeTree"
      assert sql =~ "ORDER BY (bucket, tenant_id, device_id)"
    end

    test "emits TTL from retention" do
      sql = DDL.create_table(VibrationP95, "segment_vibration_p95_v1")
      assert sql =~ "TTL bucket + INTERVAL 24 MONTH"
    end

    test "no TTL when retention is empty" do
      sql = DDL.create_table(PowerDaily, "segment_power_daily_v1")
      refute sql =~ "TTL "
    end

    test "database qualifier prefixes the table name" do
      sql = DDL.create_table(VibrationP95, "segment_vibration_p95_v1", "iot")
      assert sql =~ "CREATE TABLE IF NOT EXISTS iot.segment_vibration_p95_v1"
    end
  end

  describe "create_mv/4" do
    test "wires SELECT … FROM telemetry_<source> with State funcs and GROUP BY" do
      sql = DDL.create_mv(VibrationP95, "segment_vibration_p95_v1", "telemetry_vibration")

      assert sql =~ "CREATE MATERIALIZED VIEW IF NOT EXISTS segment_vibration_p95_v1_mv"
      assert sql =~ "TO segment_vibration_p95_v1"
      assert sql =~ "toStartOfHour(ts) AS bucket"
      assert sql =~ "quantileTDigestState(0.95)(axis_x) AS axis_x_p95_state"
      assert sql =~ "avgState(axis_x) AS axis_x_avg_state"
      assert sql =~ "countState() AS samples_state"
      assert sql =~ "FROM telemetry_vibration"
      assert sql =~ "WHERE tenant_id = 'acme'"
      assert sql =~ "GROUP BY bucket, tenant_id, device_id"
    end

    test "no WHERE when filter and raw_where are empty" do
      sql = DDL.create_mv(PowerDaily, "segment_power_daily_v1", "telemetry_power")
      refute sql =~ "WHERE "
    end
  end

  describe "create_view/2" do
    test "concatenates the table and the MV with a blank line between" do
      sql = DDL.create_view(VibrationP95)
      [table, mv] = String.split(sql, "\n\n", trim: true)
      assert table =~ "CREATE TABLE IF NOT EXISTS"
      assert mv =~ "CREATE MATERIALIZED VIEW IF NOT EXISTS"
    end

    test "honours --target opt" do
      sql = DDL.create_view(VibrationP95, target: "custom_target_v3")
      assert sql =~ "CREATE TABLE IF NOT EXISTS custom_target_v3"
      assert sql =~ "CREATE MATERIALIZED VIEW IF NOT EXISTS custom_target_v3_mv"
    end
  end

  describe "backfill_sql/3" do
    test "INSERT INTO … SELECT with an ISO-8601 floor" do
      sql =
        DDL.backfill_sql(VibrationP95, ~U[2026-01-01 00:00:00Z],
          target: "segment_vibration_p95_v1"
        )

      assert sql =~ "INSERT INTO segment_vibration_p95_v1"
      assert sql =~ "FROM telemetry_vibration"
      assert sql =~ "ts >= '2026-01-01T00:00:00Z'"
      assert sql =~ "WHERE tenant_id = 'acme' AND ts >="
    end

    test "no floor → just the segment's filter" do
      sql = DDL.backfill_sql(VibrationP95, nil, target: "segment_vibration_p95_v1")
      assert sql =~ "WHERE tenant_id = 'acme'"
      refute sql =~ "ts >="
    end

    test "no filter and no floor → no WHERE clause" do
      sql = DDL.backfill_sql(PowerDaily, nil, target: "segment_power_daily_v1")
      refute sql =~ "WHERE "
    end
  end
end
