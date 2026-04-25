defmodule SootSegments.RegistryTest do
  use ExUnit.Case, async: false

  alias SootSegments.{Registry, SegmentRow, SegmentVersion}
  alias SootSegments.Test.Factories
  alias SootSegments.Test.Fixtures.{PowerDaily, VibrationP95}

  setup do
    Factories.reset!()
    :ok
  end

  test "register/1 creates segment + version rows" do
    {:ok, %{segment: seg, version: v}} = Registry.register(VibrationP95)

    assert seg.name == :vibration_p95
    assert seg.module == VibrationP95
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

    {:ok, all_segments} = Ash.read(SegmentRow)
    assert length(all_segments) == 2

    {:ok, all_versions} = Ash.read(SegmentVersion)
    assert length(all_versions) == 2
  end

  test "registering different modules produces separate version rows" do
    {:ok, %{version: vv}} = Registry.register(VibrationP95)
    {:ok, %{version: pv}} = Registry.register(PowerDaily)
    assert vv.fingerprint != pv.fingerprint
  end
end
