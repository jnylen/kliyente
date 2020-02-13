defmodule Kliyente.ContentCache.Request do
  alias Kliyente.Request

  def cacheable?(%Request{method: method})
      when method not in ["GET", "HEAD"],
      do: false

  def cacheable?(_), do: true
end
