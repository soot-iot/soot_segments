defmodule Mix.Tasks.SootSegments.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs the SootSegments domain stub into a Phoenix/Ash project"
  end

  def example do
    "mix igniter.install soot_segments"
  end

  def long_doc do
    """
    #{short_doc()}

    Generates a `Segments` Ash domain plus `Segment` and `SegmentVersion`
    resource stubs in the operator's project, and imports the
    `:soot_segments` formatter rules.

    Composed by `mix soot.install`; can also be run standalone.

    See the `UI-SPEC.md` in the `soot` package for the full design.

    ## Example

    ```bash
    #{example()}
    ```

    ## Options

      * `--example` — same shape as the rest of the Soot installers;
        currently a no-op for `soot_segments` since the resource stubs
        already compile against the framework's defaults.
      * `--yes` — answer yes to dependency-fetching prompts.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.SootSegments.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @resources [
      "Segment",
      "SegmentVersion"
    ]

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
      |> create_segments_domain()
      |> create_resources()
      |> note_next_steps()
    end

    defp segments_domain_module(igniter) do
      Igniter.Project.Module.module_name(igniter, "Segments")
    end

    defp resource_module(igniter, resource_name) do
      Igniter.Project.Module.module_name(igniter, "Segments.#{resource_name}")
    end

    defp create_segments_domain(igniter) do
      module = segments_domain_module(igniter)

      Igniter.Project.Module.create_module(
        igniter,
        module,
        """
        @moduledoc \"\"\"
        Segments domain — owns segment definitions and the materialized
        rollups they compile to.

        Generated stub. Operators can extend with their own resources or
        replace the framework-shipped ones; the installer does not
        re-touch this file once generated.
        \"\"\"

        use Ash.Domain

        resources do
        end
        """
      )
    end

    defp create_resources(igniter) do
      domain = segments_domain_module(igniter)

      Enum.reduce(@resources, igniter, fn resource_name, igniter ->
        module = resource_module(igniter, resource_name)

        Igniter.Project.Module.create_module(
          igniter,
          module,
          """
          @moduledoc \"\"\"
          #{resource_name} resource stub for the Segments domain.

          Generated stub. Extend with attributes, actions, and policies.
          The installer does not re-touch this file once generated.
          \"\"\"

          use Ash.Resource, domain: #{inspect(domain)}

          actions do
          end
          """
        )
      end)
    end

    defp note_next_steps(igniter) do
      Igniter.add_notice(igniter, """
      soot_segments installed.

      Generated:

        lib/<app>/segments.ex                  Segments domain stub
        lib/<app>/segments/segment.ex          Segment resource stub
        lib/<app>/segments/segment_version.ex  SegmentVersion resource stub

      Next:

        mix soot_segments.gen_migrations  # emit ClickHouse MV migrations
                                          # for any segments you declare
        mix ash.codegen                   # if you added persistence to
                                          # the resources
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
