defmodule SootSegments.Test.Factories do
  @moduledoc false

  def reset! do
    for resource <- [SootSegments.SegmentRow, SootSegments.SegmentVersion] do
      try do
        :ets.delete_all_objects(resource)
      rescue
        _ -> :ok
      end
    end

    :ok
  end
end
