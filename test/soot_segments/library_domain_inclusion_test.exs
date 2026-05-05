defmodule SootSegments.LibraryDomainInclusionTest do
  @moduledoc """
  Regression: a consumer-namespaced resource declaring
  `domain: SootSegments.Domain` must compile.

  Without `allow_unregistered? true` on `SootSegments.Domain`, Ash's
  `VerifyAcceptedByDomain` verifier raises at module-load time:

      ** (RuntimeError) Resource SootSegments.LibraryDomainInclusionTest.
      ConsumerSegmentRow declared that its domain is
      SootSegments.Domain, but that domain does not accept this resource.

  If the verifier fires, this file fails to compile and the whole
  test suite errors out — that is the intended failure mode.
  """
  use ExUnit.Case, async: true

  defmodule ConsumerSegmentRow do
    @moduledoc false

    use Ash.Resource,
      otp_app: :soot_segments,
      domain: SootSegments.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [SootSegments.Resource.SegmentRow]

    ets do
      private? false
    end
  end

  test "consumer-namespaced module pointing at SootSegments.Domain compiles" do
    assert Code.ensure_loaded?(ConsumerSegmentRow)
    assert is_list(Spark.Dsl.Extension.get_entities(ConsumerSegmentRow, [:attributes]))
  end
end
