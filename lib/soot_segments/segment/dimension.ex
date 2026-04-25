defmodule SootSegments.Segment.Dimension do
  @moduledoc """
  A column the segment rolls up by (`GROUP BY` term).
  """

  defstruct [
    :name,
    :as,
    __spark_metadata__: nil
  ]

  @type t :: %__MODULE__{
          name: atom(),
          as: atom() | nil
        }
end
