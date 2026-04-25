defmodule SootSegments.SegmentRowTest do
  use ExUnit.Case, async: false

  alias SootSegments.{Registry, SegmentRow}
  alias SootSegments.Test.Factories
  alias SootSegments.Test.Fixtures.VibrationP95

  setup do
    Factories.reset!()
    {:ok, %{segment: segment}} = Registry.register(VibrationP95)
    {:ok, segment: segment}
  end

  describe "lifecycle actions" do
    test "starts :active", %{segment: segment} do
      assert segment.status == :active
    end

    test "pause/1 transitions to :paused", %{segment: segment} do
      assert {:ok, paused} = SegmentRow.pause(segment, authorize?: false)
      assert paused.status == :paused
    end

    test "resume/1 transitions back to :active", %{segment: segment} do
      {:ok, paused} = SegmentRow.pause(segment, authorize?: false)
      assert {:ok, resumed} = SegmentRow.resume(paused, authorize?: false)
      assert resumed.status == :active
    end

    test "retire/1 transitions to :retired", %{segment: segment} do
      assert {:ok, retired} = SegmentRow.retire(segment, authorize?: false)
      assert retired.status == :retired
    end
  end

  describe "get_by_name/1" do
    test "returns the segment", %{segment: segment} do
      assert {:ok, found} = SegmentRow.get_by_name(:vibration_p95, authorize?: false)
      assert found.id == segment.id
    end

    test "errors on an unknown name" do
      assert {:error, _} = SegmentRow.get_by_name(:nope, authorize?: false)
    end
  end

  describe "identity" do
    test "name is unique" do
      assert {:error, _} =
               SegmentRow.create(:vibration_p95, :other, :hour, Ash.UUID.generate(),
                 authorize?: false
               )
    end
  end
end
