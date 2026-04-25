defmodule SootSegments.Test.Factories do
  @moduledoc false

  def reset! do
    for resource <- [SootSegments.SegmentRow, SootSegments.SegmentVersion] do
      if :ets.whereis(resource) != :undefined do
        :ets.delete_all_objects(resource)
      end
    end

    :ok
  end
end
