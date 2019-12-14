defmodule ActsAs.MixProject do
  use Mix.Project

  def project do
    [
      app: :acts_as,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, ">= 3.0.0"},
      {:ecto_sql, ">= 3.0.0", only: :test},
      {:postgrex, ">= 0.15.0", only: :test},
    ]
  end
end
