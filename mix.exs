defmodule SootSegments.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :soot_segments,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SootSegments.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Segment definitions, ClickHouse materialized-view compiler, versioning, backfill helpers."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{}
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.24"},
      {:spark, "~> 2.6"},
      {:ash_pki, path: "../ash_pki"},
      {:soot_core, path: "../soot_core"},
      {:soot_telemetry, path: "../soot_telemetry"},
      {:plug, "~> 1.19"},
      {:jason, "~> 1.4"}
    ]
  end
end
