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

  describe "generated modules" do
    test "creates the Segments domain module" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_creates("lib/test/segments.ex")
    end

    test "creates the Segment resource stub" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_creates("lib/test/segments/segment.ex")
    end

    test "creates the SegmentVersion resource stub" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_creates("lib/test/segments/segment_version.ex")
    end

    test "Segment resource declares the Segments domain" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      diff = diff(result, only: "lib/test/segments/segment.ex")
      assert diff =~ "use Ash.Resource"
      assert diff =~ "Test.Segments"
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

    test "is idempotent" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_unchanged(".formatter.exs")
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
