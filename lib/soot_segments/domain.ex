defmodule SootSegments.Domain do
  @moduledoc "Ash domain for segment registry resources."

  # validate_config_inclusion?: false — this domain ships in a library;
  # the host app may not list :soot_segments in :ash_domains and that's
  # OK (the registry resources are accessed through the Registry API,
  # not user code).
  use Ash.Domain, otp_app: :soot_segments, validate_config_inclusion?: false

  resources do
    allow_unregistered? true

    resource SootSegments.SegmentRow
    resource SootSegments.SegmentVersion
  end
end
