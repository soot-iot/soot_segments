defmodule SootSegments.PoliciesTest do
  @moduledoc """
  Boundary tests for the default `policies` blocks shipped with
  `SootSegments.SegmentRow` and `SootSegments.SegmentVersion`.
  """

  use ExUnit.Case, async: false

  alias SootSegments.Actors
  alias SootSegments.Test.Factories
  alias SootSegments.Test.Fixtures.VibrationP95

  setup do
    Factories.reset!()
    {:ok, %{segment: seg, version: ver}} = SootSegments.Registry.register(VibrationP95)
    {:ok, segment: seg, version: ver}
  end

  describe "SootSegments.SegmentRow" do
    test ":registry_sync can read", %{segment: seg} do
      assert {:ok, ^seg} =
               Ash.get(SootSegments.SegmentRow, seg.id, actor: Actors.system(:registry_sync))
    end

    test "no actor is forbidden", %{segment: seg} do
      assert {:error, %Ash.Error.Forbidden{}} = Ash.get(SootSegments.SegmentRow, seg.id)
    end

    test "non-System actor is forbidden", %{segment: seg} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.get(SootSegments.SegmentRow, seg.id, actor: %{type: :user})
    end

    test "System actor with an unknown :part is forbidden", %{segment: seg} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.get(SootSegments.SegmentRow, seg.id,
                 actor: %SootSegments.Actors.System{part: :stranger}
               )
    end
  end

  describe "SootSegments.SegmentVersion" do
    test ":registry_sync can read", %{version: ver} do
      assert {:ok, ^ver} =
               Ash.get(SootSegments.SegmentVersion, ver.id, actor: Actors.system(:registry_sync))
    end

    test "no actor is forbidden", %{version: ver} do
      assert {:error, %Ash.Error.Forbidden{}} = Ash.get(SootSegments.SegmentVersion, ver.id)
    end
  end
end
