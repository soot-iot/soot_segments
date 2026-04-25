defmodule SootSegments.ClickHouse.SQLTest do
  use ExUnit.Case, async: true

  alias SootSegments.ClickHouse.SQL
  alias SootSegments.Segment.Metric

  describe "bucket_fn/1" do
    test "maps every supported granularity" do
      assert SQL.bucket_fn(:minute) == "toStartOfMinute"
      assert SQL.bucket_fn(:five_minute) == "toStartOfFiveMinute"
      assert SQL.bucket_fn(:hour) == "toStartOfHour"
      assert SQL.bucket_fn(:day) == "toStartOfDay"
    end
  end

  describe "state_expr/1" do
    test "count" do
      assert SQL.state_expr(%Metric{aggregation: :count}) == "countState()"
    end

    test "sum / avg / min / max" do
      assert SQL.state_expr(%Metric{aggregation: :sum, column: :w}) == "sumState(w)"
      assert SQL.state_expr(%Metric{aggregation: :avg, column: :w}) == "avgState(w)"
      assert SQL.state_expr(%Metric{aggregation: :min, column: :w}) == "minState(w)"
      assert SQL.state_expr(%Metric{aggregation: :max, column: :w}) == "maxState(w)"
    end

    test "quantile uses TDigest with the q value" do
      assert SQL.state_expr(%Metric{aggregation: :quantile, column: :w, q: 0.95}) ==
               "quantileTDigestState(0.95)(w)"
    end
  end

  describe "merge_expr/1" do
    test "renames the underlying state column to the metric name" do
      assert SQL.merge_expr(%Metric{aggregation: :avg, name: :w_avg}) ==
               "avgMerge(w_avg_state) AS w_avg"
    end

    test "quantile merge carries the q" do
      assert SQL.merge_expr(%Metric{aggregation: :quantile, name: :w_p95, q: 0.95}) ==
               "quantileTDigestMerge(0.95)(w_p95_state) AS w_p95"
    end
  end

  describe "state_type/1" do
    test "covers every aggregation" do
      assert SQL.state_type(%Metric{aggregation: :count}) == "AggregateFunction(count)"
      assert SQL.state_type(%Metric{aggregation: :sum}) == "AggregateFunction(sum, Float64)"
      assert SQL.state_type(%Metric{aggregation: :avg}) == "AggregateFunction(avg, Float64)"

      assert SQL.state_type(%Metric{aggregation: :quantile, q: 0.99}) ==
               "AggregateFunction(quantileTDigest(0.99), Float64)"
    end
  end

  describe "where_clause/2" do
    test "empty filter and no raw clause → empty string" do
      assert SQL.where_clause([], nil) == ""
      assert SQL.where_clause([], "") == ""
    end

    test "single equality predicate" do
      assert SQL.where_clause([tenant_id: "acme"], nil) == "WHERE tenant_id = 'acme'"
    end

    test "multiple predicates with AND" do
      assert SQL.where_clause([tenant_id: "acme", model: "x"], nil) ==
               "WHERE tenant_id = 'acme' AND model = 'x'"
    end

    test "raw_where is appended in parens" do
      assert SQL.where_clause([tenant_id: "acme"], "device_id LIKE 'TEMP-%'") ==
               "WHERE tenant_id = 'acme' AND (device_id LIKE 'TEMP-%')"
    end

    test "raw_where alone" do
      assert SQL.where_clause([], "device_id LIKE 'TEMP-%'") ==
               "WHERE (device_id LIKE 'TEMP-%')"
    end
  end

  describe "quote_value/1" do
    test "escapes single quotes by doubling" do
      assert SQL.quote_value("o'brien") == "'o''brien'"
    end

    test "numbers pass through" do
      assert SQL.quote_value(42) == "42"
      assert SQL.quote_value(3.14) == "3.14"
    end

    test "booleans become 0/1" do
      assert SQL.quote_value(true) == "1"
      assert SQL.quote_value(false) == "0"
    end

    test "atoms are quoted as strings" do
      assert SQL.quote_value(:acme) == "'acme'"
    end

    test "nil raises with a hint about IS NULL" do
      assert_raise ArgumentError, ~r/IS NULL/, fn -> SQL.quote_value(nil) end
    end
  end
end
