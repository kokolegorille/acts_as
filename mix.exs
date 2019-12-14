defmodule ActsAs.MixProject do
  use Mix.Project

  def project do
    [
      app: :acts_as,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Dyalixir
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      # Docs
      name: "ActsAs",
      source_url: "https://github.com/kokolegorille/acts_as",
      homepage_url: "https://github.com/kokolegorille/acts_as",
      docs: [
        main: "ActsAs", # The main page in the docs
        # logo: "path/to/logo.png",
        extras: ["README.md"]
      ]
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

      # Test dependencies
      {:ecto_sql, ">= 3.0.0", only: :test},
      {:postgrex, ">= 0.15.0", only: :test},

      # Dev tools
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21.2", only: :dev, runtime: false},
    ]
  end
end
