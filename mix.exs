defmodule Kliyente.MixProject do
  use Mix.Project

  @name :kliyente
  @version "0.1.0"
  @deps [{:mint, "~> 1.0"}, {:castore, "~> 0.1.5"}, {:cookie_jar, "~> 1.0"}]

  def project do
    [
      app: @name,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: @deps
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
