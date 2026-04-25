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
  """

  alias SootSegments.Fingerprint
  alias SootSegments.Segment.Info
  alias SootSegments.{SegmentRow, SegmentVersion}

  @doc "Register or update a single segment module."
  @spec register(module()) ::
          {:ok, %{segment: SegmentRow.t(), version: SegmentVersion.t()}}
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
          {:ok, [%{segment: SegmentRow.t(), version: SegmentVersion.t()}]}
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
    case SegmentVersion.get_by_fingerprint(name, fingerprint, authorize?: false) do
      {:ok, %SegmentVersion{status: :current} = version} ->
        {:ok, version}

      {:ok, %SegmentVersion{status: :deprecated} = version} ->
        deprecate_previous(name)
        SegmentVersion.promote(version, authorize?: false)

      {:ok, %SegmentVersion{status: :retired}} ->
        {:error, :cannot_reuse_retired_version}

      {:error, _} ->
        create_new_version(name, fingerprint, descriptor, target)
    end
  end

  defp create_new_version(name, fingerprint, descriptor, target) do
    {:ok, prior_versions} = SegmentVersion.for_segment(name, authorize?: false)

    Enum.each(prior_versions, fn v ->
      if v.status == :current do
        SegmentVersion.deprecate(v, authorize?: false)
      end
    end)

    version = next_version_number(prior_versions)

    case SegmentVersion.create(
           name,
           version,
           fingerprint,
           descriptor,
           DateTime.utc_now(),
           %{materialized_target: target <> "_v" <> Integer.to_string(version)},
           authorize?: false
         ) do
      {:ok, _} = ok ->
        ok

      {:error, _} = err ->
        # Concurrent register: another caller may have created the
        # row for this fingerprint or won the version-number race.
        # Re-look up by fingerprint and use that row if present.
        case SegmentVersion.get_by_fingerprint(name, fingerprint, authorize?: false) do
          {:ok, %SegmentVersion{} = existing} -> {:ok, existing}
          _ -> err
        end
    end
  end

  defp deprecate_previous(name) do
    {:ok, versions} = SegmentVersion.for_segment(name, authorize?: false)

    Enum.each(versions, fn v ->
      if v.status == :current do
        SegmentVersion.deprecate(v, authorize?: false)
      end
    end)
  end

  defp next_version_number([]), do: 1
  defp next_version_number(versions), do: Enum.max(Enum.map(versions, & &1.version)) + 1

  defp upsert_segment(module, name, %SegmentVersion{} = version) do
    case SegmentRow.get_by_name(name, authorize?: false) do
      {:ok, %SegmentRow{} = segment} ->
        if segment.current_version_id == version.id do
          {:ok, segment}
        else
          Ash.update(
            segment,
            %{current_version_id: version.id, target: version.materialized_target},
            action: :update,
            authorize?: false
          )
        end

      {:error, _} ->
        SegmentRow.create(
          name,
          Info.source_stream(module),
          Info.granularity(module),
          version.id,
          %{target: version.materialized_target},
          authorize?: false
        )
    end
  end

end
