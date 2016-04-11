defmodule Seasonal.Mixfile do
  use Mix.Project

  @version File.read!(Path.expand("lib/seasonal/version.exs", __DIR__)) |> String.strip

  def project do
    [
      app: :seasonal,
      version: @version,
      description: "A worker pool written in Elixir",
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps,
      package: package
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      applications: [:logger, :gproc]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:gproc, "~> 0.5"},
      {:uuid, "~> 1.0"},

      {:earmark, "~> 0.1", only: :dev},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp package do
    [
      contributors: ["Lee Dohm", "Luper Rouch"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/lee-dohm/seasonal"}
    ]
  end
end
