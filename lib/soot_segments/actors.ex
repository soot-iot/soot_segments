defmodule SootSegments.Actors do
  @moduledoc """
  Actor factory for `soot_segments`.

  One System part: `:registry_sync` — internal segment / version
  upserts and deprecations performed by `SootSegments.Registry`.
  Reads from `SootSegments.Query` use the same part for the
  registry-side lookup that backs querying.

  See umbrella `soot/POLICY-SPEC.md` for the cross-library actor
  contract.
  """

  alias SootSegments.Actors.System

  @type system_part :: System.part()

  @doc "Build a `System` actor for an internal subsystem."
  @spec system(system_part()) :: System.t()
  def system(part) when is_atom(part), do: %System{part: part}

  @spec system(system_part(), keyword() | binary() | nil) :: System.t()
  def system(part, tenant_id) when is_atom(part) and is_binary(tenant_id),
    do: %System{part: part, tenant_id: tenant_id}

  def system(part, nil) when is_atom(part), do: %System{part: part}

  def system(part, opts) when is_atom(part) and is_list(opts),
    do: %System{part: part, tenant_id: Keyword.get(opts, :tenant_id)}
end
