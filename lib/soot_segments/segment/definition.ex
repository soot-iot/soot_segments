defmodule SootSegments.Segment.Definition do
  @moduledoc """
  Use this in a host module to opt into the segment DSL.

      defmodule MyApp.Segments.VibrationP95 do
        use SootSegments.Segment.Definition

        segment do
          name :vibration_p95
          source_stream :vibration
          ...
        end
      end

  Equivalent to
  `use Spark.Dsl, default_extensions: [extensions: [SootSegments.Segment]]`,
  which is also a perfectly valid spelling.
  """

  use Spark.Dsl, default_extensions: [extensions: [SootSegments.Segment]]
end
