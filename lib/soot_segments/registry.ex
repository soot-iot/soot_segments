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
        deprecate_previous(name)

        version = next_version(name)

        SegmentVersion.create(
          name,
          version,
          fingerprint,
          descriptor,
          DateTime.utc_now(),
          %{materialized_target: target_with_version(target, version)},
          authorize?: false
        )
    end
  end

  defp deprecate_previous(name) do
    case SegmentVersion.for_segment(name, authorize?: false) do
      {:ok, versions} ->
        Enum.each(versions, fn v ->
          if v.status == :current do
            SegmentVersion.deprecate(v, authorize?: false)
          end
        end)

      _ ->
        :ok
    end
  end

  defp next_version(name) do
    case SegmentVersion.for_segment(name, authorize?: false) do
      {:ok, []} -> 1
      {:ok, versions} -> (Enum.map(versions, & &1.version) |> Enum.max()) + 1
      _ -> 1
    end
  end

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
          module,
          Info.source_stream(module),
          Info.granularity(module),
          version.id,
          %{target: version.materialized_target},
          authorize?: false
        )
    end
  end

  defp target_with_version(target, version) when is_binary(target) do
    target <> "_v" <> Integer.to_string(version)
  end
end
