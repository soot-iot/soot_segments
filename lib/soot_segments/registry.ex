defmodule SootSegments.Registry do
  @moduledoc """
  Walks segment-DSL modules and upserts `SegmentRow` + `SegmentVersion`
  rows.

  When a module's fingerprint matches an existing version, that version
  stays current. When it differs, a new `SegmentVersion` row is created
  with `status: :current` and `date_floor: now()`, the previous current
  version is moved to `:deprecated`, and `SegmentRow.current_version_id`
  is updated.

  Old MV tables are not dropped; operators decide retention so they can
  serve historical data from old versions if they want.

  Resource modules are resolved through `SootSegments.segment_row/0`
  and `SootSegments.segment_version/0` so consumer overrides registered
  via app config (`config :soot_segments, segment_row: MyApp.SegmentRow`,
  etc.) are honoured at runtime.
  """

  alias SootSegments.Fingerprint
  alias SootSegments.Segment.Info

  @doc "Register or update a single segment module."
  @spec register(module()) ::
          {:ok, %{segment: struct(), version: struct()}}
          | {:error, term()}
  def register(module) when is_atom(module) do
    name = Info.name(module)
    fingerprint = Fingerprint.compute(module)
    descriptor = Fingerprint.descriptor(module)

    with {:ok, version} <- ensure_version(name, fingerprint, descriptor, Info.target(module)),
         {:ok, segment} <- upsert_segment(module, name, version) do
      {:ok, %{segment: segment, version: version}}
    end
  end

  @doc "Register every module in `modules`. Halts on the first error."
  @spec register_all([module()]) ::
          {:ok, [%{segment: struct(), version: struct()}]}
          | {:error, term()}
  def register_all(modules) when is_list(modules) do
    Enum.reduce_while(modules, {:ok, []}, fn module, {:ok, acc} ->
      case register(module) do
        {:ok, result} -> {:cont, {:ok, [result | acc]}}
        err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      err -> err
    end
  end

  defp ensure_version(name, fingerprint, descriptor, target) do
    version_module = SootSegments.segment_version()

    case version_module.get_by_fingerprint(name, fingerprint,
           actor: SootSegments.Actors.system(:registry_sync)
         ) do
      {:ok, %{status: :current} = version} ->
        {:ok, version}

      {:ok, %{status: :deprecated} = version} ->
        deprecate_previous(name)
        version_module.promote(version, actor: SootSegments.Actors.system(:registry_sync))

      {:ok, %{status: :retired}} ->
        {:error, :cannot_reuse_retired_version}

      {:error, _} ->
        create_new_version(name, fingerprint, descriptor, target)
    end
  end

  defp create_new_version(name, fingerprint, descriptor, target) do
    version_module = SootSegments.segment_version()

    {:ok, prior_versions} =
      version_module.for_segment(name, actor: SootSegments.Actors.system(:registry_sync))

    Enum.each(prior_versions, fn v ->
      if v.status == :current do
        version_module.deprecate(v, actor: SootSegments.Actors.system(:registry_sync))
      end
    end)

    version = next_version_number(prior_versions)

    case version_module.create(
           name,
           version,
           fingerprint,
           descriptor,
           DateTime.utc_now(),
           %{materialized_target: target <> "_v" <> Integer.to_string(version)},
           actor: SootSegments.Actors.system(:registry_sync)
         ) do
      {:ok, _} = ok ->
        ok

      {:error, _} = err ->
        # Concurrent register: another caller may have created the
        # row for this fingerprint or won the version-number race.
        # Re-look up by fingerprint and use that row if present.
        case version_module.get_by_fingerprint(name, fingerprint,
               actor: SootSegments.Actors.system(:registry_sync)
             ) do
          {:ok, %_{} = existing} -> {:ok, existing}
          _ -> err
        end
    end
  end

  defp deprecate_previous(name) do
    version_module = SootSegments.segment_version()

    {:ok, versions} =
      version_module.for_segment(name, actor: SootSegments.Actors.system(:registry_sync))

    Enum.each(versions, fn v ->
      if v.status == :current do
        version_module.deprecate(v, actor: SootSegments.Actors.system(:registry_sync))
      end
    end)
  end

  defp next_version_number([]), do: 1
  defp next_version_number(versions), do: Enum.max(Enum.map(versions, & &1.version)) + 1

  defp upsert_segment(module, name, version) do
    segment_module = SootSegments.segment_row()

    case segment_module.get_by_name(name, actor: SootSegments.Actors.system(:registry_sync)) do
      {:ok, %_{} = segment} ->
        if segment.current_version_id == version.id do
          {:ok, segment}
        else
          Ash.update(
            segment,
            %{current_version_id: version.id, target: version.materialized_target},
            action: :update,
            actor: SootSegments.Actors.system(:registry_sync)
          )
        end

      {:error, _} ->
        segment_module.create(
          name,
          Info.source_stream(module),
          Info.granularity(module),
          version.id,
          %{target: version.materialized_target},
          actor: SootSegments.Actors.system(:registry_sync)
        )
    end
  end
end
