# ActsAs

An Ecto replacement for Rails Activerecord plugins acts_as_list, awesome_nested_set.

* dependency: 
  {:ecto, ">= 3.0.0"},

* test dependencies:
  {:ecto_sql, ">= 3.0.0", only: :test},
  {:postgrex, ">= 0.15.0", only: :test},

* dev dependencies:
  {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
  {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
  {:ex_doc, "~> 0.21.2", only: :dev, runtime: false},

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `acts_as` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:acts_as, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/acts_as](https://hexdocs.pm/acts_as).

## Ex Doc

$ mix escript.install hex ex_doc
$ ~/.asdf/installs/elixir/1.9.1-otp-22/.mix/escripts/ex_doc "ActsAs" "0.0.1" _build/dev/lib/acts_as/ebin/

## Ecto plugin

To test the library, You need to set dummy environment in test/test_helper.exs

## Configure logger for tests

Add config/config.exs
Add config/test.exs

Set config :logger, level: :warn