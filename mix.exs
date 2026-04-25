defmodule SootSegments.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/lawik/soot_segments"

  def project do
    [
      app: :soot_segments,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    "Segment definitions, ClickHouse materialized-view compiler, versioning, backfill helpers."
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
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
