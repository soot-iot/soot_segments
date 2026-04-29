defmodule SootSegments.ActorsTest do
  use ExUnit.Case, async: true

  alias SootSegments.Actors
  alias SootSegments.Actors.System

  test "system/1 builds a System actor" do
    assert %System{part: :registry_sync, tenant_id: nil} = Actors.system(:registry_sync)
  end

  test "system/2 with binary tenant_id" do
    assert %System{tenant_id: "t-1"} = Actors.system(:registry_sync, "t-1")
  end

  test "system/2 with nil tenant" do
    assert %System{tenant_id: nil} = Actors.system(:registry_sync, nil)
  end

  test "system/2 with keyword opts" do
    assert %System{tenant_id: "t-x"} = Actors.system(:registry_sync, tenant_id: "t-x")
  end

  test "%System{} enforces :part" do
    assert_raise ArgumentError, fn -> struct!(System, []) end
  end
end
