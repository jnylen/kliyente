# Kliyente

Kliyente is a HTTP Client that uses Mint and CookieJar for fetching and caching downloads on the harddrive.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kliyente` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kliyente, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/kliyente](https://hexdocs.pm/kliyente).

## Usage

```elixir
Kliyente.open("httpbin.org", ssl: true)
|> Kliyente.get("/cookie/set?cooke=value")
```

## Credits

Some parts are copied straight from Mojito and CookieJar.
