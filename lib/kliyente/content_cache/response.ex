defmodule Kliyente.ContentCache.Response do
  alias Kliyente.Response

  @cacheable_status [200, 203, 300, 301, 302, 307, 404, 410]
  def cacheable?(%Response{status_code: status}) when status in @cacheable_status,
    do: true

  def cacheable?(_), do: false

  def fresh?(%Response{}) do
    false
  end
end
