defmodule Mix.Tasks.SootSegments.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  defp setup_project do
    test_project(files: %{})
  end

  describe "info/2" do
    test "exposes the documented option schema" do
      info = Mix.Tasks.SootSegments.Install.info([], nil)
      assert info.group == :soot
      assert info.schema == [example: :boolean, yes: :boolean]
      assert info.aliases == [y: :yes, e: :example]
    end
  end

  describe "domain registration" do
    test "registers SootSegments.Domain in operator's :ash_domains" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      diff = diff(result, only: "config/config.exs")
      assert diff =~ "SootSegments.Domain"
      assert diff =~ "ash_domains:"
    end
  end

  describe "formatter" do
    test "imports the :soot_segments formatter rules" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_has_patch(".formatter.exs", """
      + |  import_deps: [:soot_segments]
      """)
    end
  end

  describe "idempotency" do
    test "running twice is a no-op on .formatter.exs" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_unchanged(".formatter.exs")
    end

    test "running twice does not re-add SootSegments.Domain to :ash_domains" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_unchanged("config/config.exs")
    end
  end

  describe "next-steps notice" do
    test "always emits a soot_segments installed notice" do
      igniter =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      assert Enum.any?(igniter.notices, &(&1 =~ "soot_segments installed"))
    end

    test "mentions the gen_migrations follow-up" do
      igniter =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      assert Enum.any?(igniter.notices, &(&1 =~ "soot_segments.gen_migrations"))
    end
  end
end
