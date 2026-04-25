defmodule SootSegments.SegmentVersionTest do
  use ExUnit.Case, async: false

  alias SootSegments.{Registry, SegmentVersion}
  alias SootSegments.Test.Factories
  alias SootSegments.Test.Fixtures.{VibrationP95, VibrationP95V2}

  setup do
    Factories.reset!()
    {:ok, %{version: v1}} = Registry.register(VibrationP95)
    {:ok, version: v1}
  end

  describe "lifecycle actions" do
    test "starts :current", %{version: v} do
      assert v.status == :current
    end

    test "deprecate/1 transitions to :deprecated", %{version: v} do
      assert {:ok, dep} = SegmentVersion.deprecate(v, authorize?: false)
      assert dep.status == :deprecated
    end

    test "promote/1 transitions :deprecated back to :current", %{version: v} do
      {:ok, dep} = SegmentVersion.deprecate(v, authorize?: false)
      assert {:ok, prom} = SegmentVersion.promote(dep, authorize?: false)
      assert prom.status == :current
    end

    test "retire/1 transitions to :retired", %{version: v} do
      assert {:ok, ret} = SegmentVersion.retire(v, authorize?: false)
      assert ret.status == :retired
    end
  end

  describe "get_by_fingerprint/2" do
    test "returns the version for a known (segment_name, fingerprint) pair", %{version: v} do
      assert {:ok, found} =
               SegmentVersion.get_by_fingerprint(:vibration_p95, v.fingerprint, authorize?: false)

      assert found.id == v.id
    end

    test "errors when the fingerprint is unknown" do
      assert {:error, _} =
               SegmentVersion.get_by_fingerprint(:vibration_p95, "nope", authorize?: false)
    end
  end

  describe "for_segment/1" do
    test "returns every version, sorted by version desc", %{version: v1} do
      {:ok, _} = Registry.register(VibrationP95V2)

      {:ok, versions} = SegmentVersion.for_segment(:vibration_p95, authorize?: false)

      assert Enum.map(versions, & &1.version) == [2, 1]
      assert hd(Enum.reverse(versions)).id == v1.id
    end

    test "returns [] for an unknown segment" do
      assert {:ok, []} = SegmentVersion.for_segment(:unknown, authorize?: false)
    end
  end

  describe "identities" do
    test "version is unique per segment_name", %{version: v} do
      assert {:error, _} =
               SegmentVersion.create(
                 :vibration_p95,
                 v.version,
                 "different-fingerprint",
                 %{},
                 DateTime.utc_now(),
                 authorize?: false
               )
    end

    test "fingerprint is unique per segment_name", %{version: v} do
      assert {:error, _} =
               SegmentVersion.create(
                 :vibration_p95,
                 99,
                 v.fingerprint,
                 %{},
                 DateTime.utc_now(),
                 authorize?: false
               )
    end
  end
end
