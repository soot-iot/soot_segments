defmodule SootSegments.Actors.System do
  @moduledoc """
  Internal-subsystem actor for `soot_segments`. See
  `SootSegments.Actors`.
  """

  @enforce_keys [:part]
  defstruct [:part, :tenant_id]

  @type part :: :registry_sync

  @type t :: %__MODULE__{
          part: part(),
          tenant_id: String.t() | nil
        }
end
