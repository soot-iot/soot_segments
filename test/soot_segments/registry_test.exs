defmodule SootSegments.RegistryTest do
  use ExUnit.Case, async: false

  alias SootSegments.{Registry, SegmentRow, SegmentVersion}
  alias SootSegments.Test.Factories
  alias SootSegments.Test.Fixtures.{PowerDaily, VibrationP95, VibrationP95V2}

  setup do
    Factories.reset!()
    :ok
  end

  test "register/1 creates segment + version rows" do
    {:ok, %{segment: seg, version: v}} = Registry.register(VibrationP95)

    assert seg.name == :vibration_p95
    assert seg.source_stream == :vibration
    assert seg.granularity == :hour
    assert seg.current_version_id == v.id
    assert seg.target == v.materialized_target

    assert v.segment_name == :vibration_p95
    assert v.version == 1
    assert v.fingerprint =~ ~r/^[0-9a-f]{64}$/
    assert v.materialized_target == "segment_vibration_p95_v1"
    assert v.status == :current
    assert %DateTime{} = v.date_floor
  end

  test "register/1 is idempotent for an unchanged module" do
    {:ok, %{version: v1}} = Registry.register(VibrationP95)
    {:ok, %{version: v2}} = Registry.register(VibrationP95)
    assert v1.id == v2.id
  end

  test "register_all/1 returns one result per module" do
    {:ok, results} = Registry.register_all([VibrationP95, PowerDaily])
    assert length(results) == 2

    {:ok, all_segments} = Ash.read(SegmentRow, authorize?: false)
    assert length(all_segments) == 2

    {:ok, all_versions} = Ash.read(SegmentVersion, authorize?: false)
    assert length(all_versions) == 2
  end

  test "registering different modules produces separate version rows" do
    {:ok, %{version: vv}} = Registry.register(VibrationP95)
    {:ok, %{version: pv}} = Registry.register(PowerDaily)
    assert vv.fingerprint != pv.fingerprint
  end

  describe "definition change" do
    test "creates a new version, deprecates the prior current, and updates the SegmentRow" do
      {:ok, %{segment: seg_v1, version: v1}} = Registry.register(VibrationP95)
      {:ok, %{segment: seg_v2, version: v2}} = Registry.register(VibrationP95V2)

      assert v2.version == 2
      assert v2.status == :current
      assert v2.materialized_target == "segment_vibration_p95_v2"

      assert {:ok, reloaded_v1} = Ash.get(SegmentVersion, v1.id, authorize?: false)
      assert reloaded_v1.status == :deprecated

      assert seg_v2.id == seg_v1.id
      assert seg_v2.current_version_id == v2.id
      assert seg_v2.target == v2.materialized_target
    end

    test "re-registering a deprecated fingerprint promotes it back to current" do
      {:ok, %{version: v1}} = Registry.register(VibrationP95)
      {:ok, %{version: v2}} = Registry.register(VibrationP95V2)

      # Roll back: re-register the original fixture
      {:ok, %{segment: seg, version: rolled}} = Registry.register(VibrationP95)

      assert rolled.id == v1.id
      assert rolled.status == :current
      assert seg.current_version_id == v1.id
      assert seg.target == v1.materialized_target

      assert {:ok, reloaded_v2} = Ash.get(SegmentVersion, v2.id, authorize?: false)
      assert reloaded_v2.status == :deprecated
    end

    test "refuses to reuse a retired version" do
      {:ok, %{version: v1}} = Registry.register(VibrationP95)
      {:ok, _} = SegmentVersion.retire(v1, authorize?: false)

      assert {:error, :cannot_reuse_retired_version} = Registry.register(VibrationP95)
    end
  end

  describe "register_all/1" do
    test "halts on the first error returned by register/1 and returns it" do
      # Force a structured error from the second module: retire
      # VibrationP95's v1, then attempt to re-register it after V2.
      {:ok, %{version: v1}} = Registry.register(VibrationP95)
      {:ok, _} = SegmentVersion.retire(v1, authorize?: false)

      assert {:error, :cannot_reuse_retired_version} =
               Registry.register_all([VibrationP95V2, VibrationP95])

      # The first module of the list still made it through.
      {:ok, versions} = SegmentVersion.for_segment(:vibration_p95, authorize?: false)
      versions_by_v = Map.new(versions, &{&1.version, &1.status})
      assert versions_by_v[1] == :retired
      assert versions_by_v[2] == :current
    end
  end
end
