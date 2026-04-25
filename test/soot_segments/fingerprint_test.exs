defmodule SootSegments.FingerprintTest do
  use ExUnit.Case, async: true

  alias SootSegments.Fingerprint
  alias SootSegments.Test.Fixtures.{PowerDaily, VibrationP95}

  test "is deterministic across calls" do
    assert Fingerprint.compute(VibrationP95) == Fingerprint.compute(VibrationP95)
  end

  test "differs between modules with different metrics" do
    refute Fingerprint.compute(VibrationP95) == Fingerprint.compute(PowerDaily)
  end

  test "is hex-encoded SHA-256" do
    assert Fingerprint.compute(VibrationP95) =~ ~r/^[0-9a-f]{64}$/
  end

  test "key ordering inside the descriptor doesn't break the hash" do
    canonical = Fingerprint.descriptor(VibrationP95)
    shuffled = canonical |> Map.to_list() |> Enum.reverse() |> Map.new()

    assert Fingerprint.compute_descriptor(canonical) ==
             Fingerprint.compute_descriptor(shuffled)
  end

  test "metric changes alter the fingerprint" do
    base = Fingerprint.descriptor(VibrationP95)

    mutated =
      Map.update!(base, :metrics, fn metrics ->
        metrics ++ [%{name: :extra, aggregation: :sum, column: :extra, q: nil}]
      end)

    refute Fingerprint.compute_descriptor(base) == Fingerprint.compute_descriptor(mutated)
  end

  test "filter changes alter the fingerprint" do
    base = Fingerprint.descriptor(VibrationP95)
    mutated = Map.put(base, :filter, %{tenant_id: "other"})

    refute Fingerprint.compute_descriptor(base) == Fingerprint.compute_descriptor(mutated)
  end
end
