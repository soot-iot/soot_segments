defmodule Mix.Tasks.SootSegments.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs soot_segments: registers the framework's Segments domain in the operator's project"
  end

  def example do
    "mix igniter.install soot_segments"
  end

  def long_doc do
    """
    #{short_doc()}

    `SootSegments.Domain` ships its `SegmentRow` and `SegmentVersion`
    resources as concrete library modules. The installer registers
    that domain in the operator's `:ash_domains` config rather than
    generating empty stub copies.

    soot_segments is purely server-side rollups — there is no router
    work to do. The library wires up the materialized-view machinery
    behind the scenes; operators interact with it via the registry
    API and `mix soot_segments.gen_migrations`.

    Composed by `mix soot.install`; can also be run standalone.

    See `GENERATOR-SPEC.md` in the `soot` package for the full design.

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

      * `--example` — accepted for parity with the other Soot
        installers; currently a no-op for `soot_segments`.
      * `--yes` — answer yes to dependency-fetching prompts.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.SootSegments.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :soot,
        example: __MODULE__.Docs.example(),
        only: nil,
        composes: [],
        schema: [example: :boolean, yes: :boolean],
        defaults: [example: false, yes: false],
        aliases: [y: :yes, e: :example]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:soot_segments)
      |> register_domain()
      |> note_next_steps()
    end

    defp register_domain(igniter) do
      app = Igniter.Project.Application.app_name(igniter)

      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        app,
        [:ash_domains],
        [SootSegments.Domain],
        updater: fn list ->
          Igniter.Code.List.prepend_new_to_list(list, SootSegments.Domain)
        end
      )
    end

    defp note_next_steps(igniter) do
      Igniter.add_notice(igniter, """
      soot_segments installed.

      `SootSegments.Domain` is registered in `:ash_domains`. The
      `SegmentRow` and `SegmentVersion` resources ship with the
      library — operators do not need their own copies.

      Next:

        mix soot_segments.gen_migrations  # emit ClickHouse MV migrations
                                          # for any segments you declare
      """)
    end
  end
else
  defmodule Mix.Tasks.SootSegments.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"
    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task `soot_segments.install` requires igniter. Add
      `{:igniter, "~> 0.6"}` to your project deps and try again, or
      invoke via:

          mix igniter.install soot_segments

      For more information, see https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
