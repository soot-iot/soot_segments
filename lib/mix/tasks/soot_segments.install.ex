defmodule Mix.Tasks.SootSegments.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs soot_segments: registers the Segments domain and generates AshPostgres-backed SegmentRow + SegmentVersion"
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
    generating empty stub copies of the library defaults.

    The library defaults run on `Ash.DataLayer.Ets` so the
    soot_segments test suite can run with zero infra, but Postgres is
    mandatory in the soot stack. The installer therefore composes
    `ash_postgres.install` (wiring the consumer's Repo + the
    `:ash_postgres` dep) and generates two AshPostgres-backed consumer
    resource modules under `lib/<app>/`:

      * `<App>.SegmentRow` — table `segment_rows`
      * `<App>.SegmentVersion` — table `segment_versions`

    Each generated module applies the matching
    `SootSegments.Resource.<Name>` extension which contributes the
    schema (attributes, identities, lifecycle actions). The modules
    are then registered in `config/config.exs` under
    `:soot_segments, segment_row:` / `:soot_segments, segment_version:`
    so the rest of soot_segments picks them up at boot. Operators
    own the generated files post-install — edit the `postgres do … end`
    block, add custom actions, etc. as needed.

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

    @resources [
      %{
        name: "SegmentRow",
        config_key: :segment_row,
        table: "segment_rows",
        extension: SootSegments.Resource.SegmentRow
      },
      %{
        name: "SegmentVersion",
        config_key: :segment_version,
        table: "segment_versions",
        extension: SootSegments.Resource.SegmentVersion
      }
    ]

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :soot,
        example: __MODULE__.Docs.example(),
        only: nil,
        composes: ["ash_postgres.install"],
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
      |> compose_ash_postgres()
      |> generate_consumer_resources()
      |> register_consumer_resources()
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

    # `ash_postgres.install` handles the `:ash_postgres` dep, the Repo
    # module, the `:ecto_repos` config, and dev/test/runtime DB URLs.
    # Threading `--yes` through keeps the install non-interactive when
    # the parent installer is running with `-y`. The third-arg fallback
    # is a no-op so the installer's own test suite (which runs without
    # ash_postgres in deps) can still exercise the rest of the
    # pipeline; in real consumer projects `ash_postgres.install` is
    # available because the parent `mix igniter.install` resolves it.
    defp compose_ash_postgres(igniter) do
      argv = if igniter.args.options[:yes], do: ["--yes"], else: []
      Igniter.compose_task(igniter, "ash_postgres.install", argv, & &1)
    end

    defp generate_consumer_resources(igniter) do
      Enum.reduce(@resources, igniter, &generate_consumer_resource/2)
    end

    defp generate_consumer_resource(spec, igniter) do
      module = consumer_module(igniter, spec.name)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, module)

      if exists? do
        igniter
      else
        repo = Igniter.Project.Module.module_name(igniter, "Repo")
        body = consumer_module_body(igniter, spec, repo)
        Igniter.Project.Module.create_module(igniter, module, body)
      end
    end

    defp register_consumer_resources(igniter) do
      Enum.reduce(@resources, igniter, &register_consumer_resource/2)
    end

    defp register_consumer_resource(spec, igniter) do
      module = consumer_module(igniter, spec.name)

      Igniter.Project.Config.configure(
        igniter,
        "config.exs",
        :soot_segments,
        [spec.config_key],
        module
      )
    end

    defp consumer_module(igniter, name) do
      Igniter.Project.Module.module_name(igniter, name)
    end

    defp consumer_module_body(igniter, spec, repo) do
      module = consumer_module(igniter, spec.name)

      """
      @moduledoc \"\"\"
      AshPostgres-backed `#{spec.name}` resource generated by
      `mix soot_segments.install`. Operators own this file — edit the
      `postgres do … end` block, add domain-specific actions, etc. as
      needed. The schema (attributes, identities, lifecycle actions)
      comes from the `#{inspect(spec.extension)}` extension.
      Registered via
      `config :soot_segments, #{spec.config_key}: #{inspect(module)}`.
      \"\"\"

      use Ash.Resource,
        otp_app: :#{otp_app(igniter)},
        domain: SootSegments.Domain,
        data_layer: AshPostgres.DataLayer,
        authorizers: [Ash.Policy.Authorizer],
        extensions: [#{inspect(spec.extension)}]

      postgres do
        table "#{spec.table}"
        repo #{inspect(repo)}
      end

      # Default policies (POLICY-SPEC §4.1).
      policies do
        bypass actor_attribute_equals(:role, :admin) do
          authorize_if always()
        end

        policy always() do
          access_type :strict
          authorize_if actor_attribute_equals(:part, :registry_sync)
        end
      end
      """
    end

    defp otp_app(igniter), do: Igniter.Project.Application.app_name(igniter)

    defp note_next_steps(igniter) do
      Igniter.add_notice(igniter, """
      soot_segments installed.

      `SootSegments.Domain` is registered in `:ash_domains`. The
      AshPostgres-backed `SegmentRow` and `SegmentVersion` consumer
      resources have been generated under `lib/<app>/segment_row.ex`
      and `lib/<app>/segment_version.ex` and registered in
      `config/config.exs` under `:soot_segments, segment_row:` /
      `:soot_segments, segment_version:`. The Repo module and
      `:ash_postgres` dep were wired by the composed
      `ash_postgres.install`.

      Operators own the generated resource files — edit the
      `postgres do … end` blocks, add custom actions, etc. as needed.

      Next steps:

        mix ash.codegen --name install_soot_segments
        mix ash.setup
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
