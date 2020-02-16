defmodule Kliyente.Request do
  @moduledoc false

  defstruct method: nil,
            path: nil,
            headers: [],
            body: nil,
            opts: [],
            previous_locations: []

  alias Kliyente.{Client, ContentCache, Request}

  # INCOMING CALL
  def call(
        conn,
        %Request{opts: opts} = request
      ) do
    # Can be cached?
    if ContentCache.Request.cacheable?(request) and ContentCache.has_required_opts?(opts) do
      conn
      |> ContentCache.process(request)
    else
      conn
      |> Client.run(request)
    end
  end
end
