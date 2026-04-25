defmodule SootSegments.Test.Fixtures.VibrationP95 do
  @moduledoc false
  use SootSegments.Segment.Definition

  segment do
    name :vibration_p95
    source_stream(:vibration)
    granularity(:hour)
    retention(months: 24)

    filter tenant_id: "acme"

    dimensions do
      dimension(:tenant_id)
      dimension(:device_id)
    end

    metrics do
      metric(:axis_x_p95, :quantile, column: :axis_x, q: 0.95)
      metric(:axis_x_avg, :avg, column: :axis_x)
      metric(:samples, :count)
    end
  end
end

defmodule SootSegments.Test.Fixtures.PowerDaily do
  @moduledoc false
  use SootSegments.Segment.Definition

  segment do
    name :power_daily
    source_stream(:power)
    granularity(:day)

    dimensions do
      dimension(:tenant_id)
      dimension(:device_id)
    end

    metrics do
      metric(:watts_avg, :avg, column: :watts)
      metric(:watts_max, :max, column: :watts)
    end
  end
end
