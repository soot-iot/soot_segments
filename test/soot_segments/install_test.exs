defmodule Mix.Tasks.SootSegments.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  # Igniter evaluates the consumer project's `config/config.exs` into
  # the live `Application` env so installer steps can inspect it. That
  # means our "register the consumer resource modules" step leaks
  # `Test.SegmentRow` / `Test.SegmentVersion` into the soot_segments
  # app env for the rest of this test run, which can break any
  # subsequent test that resolves `:soot_segments, :segment_row` (or
  # `:segment_version`) via config. Snapshot the relevant keys before
  # each test and restore on exit.
  setup do
    keys = [
      :segment_row,
      :segment_version
    ]

    snapshot =
      for key <- keys,
          {:ok, value} <- [Application.fetch_env(:soot_segments, key)],
          do: {key, value}

    on_exit(fn ->
      for key <- keys do
        Application.delete_env(:soot_segments, key)
      end

      for {key, value} <- snapshot do
        Application.put_env(:soot_segments, key, value)
      end
    end)

    :ok
  end

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

  describe "info/2 composes" do
    test "composes ash_postgres.install" do
      info = Mix.Tasks.SootSegments.Install.info([], nil)
      assert info.composes == ["ash_postgres.install"]
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

    test "notice mentions the generated AshPostgres-backed resources" do
      igniter =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      assert Enum.any?(igniter.notices, &(&1 =~ "AshPostgres-backed"))
      assert Enum.any?(igniter.notices, &(&1 =~ "SegmentRow"))
      assert Enum.any?(igniter.notices, &(&1 =~ "SegmentVersion"))
    end

    test "notice mentions ash.codegen + ash.setup" do
      igniter =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      assert Enum.any?(igniter.notices, &(&1 =~ "mix ash.codegen --name install_soot_segments"))
      assert Enum.any?(igniter.notices, &(&1 =~ "mix ash.setup"))
    end
  end

  describe "AshPostgres consumer resources" do
    @segment_row_path "lib/test/segment_row.ex"
    @segment_version_path "lib/test/segment_version.ex"

    defp generated_source(igniter, path) do
      source = igniter.rewrite.sources[path]

      assert source,
             "expected #{inspect(path)} to have been generated, but it was not. " <>
               "Created files: #{inspect(Map.keys(igniter.rewrite.sources))}"

      Rewrite.Source.get(source, :content)
    end

    test "generates the SegmentRow consumer resource module under lib/<app>/" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_creates(@segment_row_path)
    end

    test "generates the SegmentVersion consumer resource module under lib/<app>/" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_creates(@segment_version_path)
    end

    test "SegmentRow module wires AshPostgres + the SootSegments.Resource.SegmentRow extension" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      content = generated_source(result, @segment_row_path)

      assert content =~ "defmodule Test.SegmentRow"
      assert content =~ "use Ash.Resource"
      assert content =~ "otp_app: :test"
      assert content =~ "domain: SootSegments.Domain"
      assert content =~ "data_layer: AshPostgres.DataLayer"
      assert content =~ "extensions: [SootSegments.Resource.SegmentRow]"
      assert content =~ ~s|table("segment_rows")|
      assert content =~ "repo(Test.Repo)"
    end

    test "SegmentVersion module wires AshPostgres + the SootSegments.Resource.SegmentVersion extension" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      content = generated_source(result, @segment_version_path)

      assert content =~ "defmodule Test.SegmentVersion"
      assert content =~ "use Ash.Resource"
      assert content =~ "otp_app: :test"
      assert content =~ "domain: SootSegments.Domain"
      assert content =~ "data_layer: AshPostgres.DataLayer"
      assert content =~ "extensions: [SootSegments.Resource.SegmentVersion]"
      assert content =~ ~s|table("segment_versions")|
      assert content =~ "repo(Test.Repo)"
    end

    test "registers Test.SegmentRow in config/config.exs under :soot_segments" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      diff = diff(result, only: "config/config.exs")

      assert diff =~ "segment_row: Test.SegmentRow"
    end

    test "registers Test.SegmentVersion in config/config.exs under :soot_segments" do
      result =
        setup_project()
        |> Igniter.compose_task("soot_segments.install", [])

      diff = diff(result, only: "config/config.exs")

      assert diff =~ "segment_version: Test.SegmentVersion"
    end

    test "running the installer twice does not churn lib/test/segment_row.ex" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_unchanged(@segment_row_path)
    end

    test "running the installer twice does not churn lib/test/segment_version.ex" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_unchanged(@segment_version_path)
    end

    test "running the installer twice does not churn config/config.exs" do
      setup_project()
      |> Igniter.compose_task("soot_segments.install", [])
      |> apply_igniter!()
      |> Igniter.compose_task("soot_segments.install", [])
      |> assert_unchanged("config/config.exs")
    end
  end
end
