defmodule SootSegments.Domain do
  @moduledoc "Ash domain for segment registry resources."
  use Ash.Domain, otp_app: :soot_segments, validate_config_inclusion?: false

  resources do
    resource SootSegments.SegmentRow
    resource SootSegments.SegmentVersion
  end
end
