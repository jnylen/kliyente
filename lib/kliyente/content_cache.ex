defmodule Kliyente.ContentCache do
  defstruct file_name: nil, folder_name: nil, module: nil

  alias Kliyente.{ContentCache, Header, Client, Response}

  def process(conn, request) do
    # SKIP?
    request
    |> fetch()
    |> case do
      {:ok, %Response{} = response} ->
        cond do
          ContentCache.Response.check?(response) ->
            {:ok, response}

          ContentCache.Response.fresh?(response) ->
            {:ok, response}

          true ->
            with {:ok, response} <- validate(conn, request, response) do
              ContentCache.File.store(request, response)
            end
        end

      {:error, _} ->
        run_and_store(conn, request)
    end
  end

  def has_required_opts?(opts) do
    if Keyword.get(opts, :file_name, false) and Keyword.get(opts, :folder_name, false) do
      true
    else
      false
    end
  end

  defp run_and_store(conn, request) do
    with {:ok, response} <- Client.run(conn, request) do
      ContentCache.File.store(request, response)
    end
  end

  # Fetch
  defp fetch(request) do
    with {:ok, response} <- ContentCache.File.get(request) do
      {:ok, ContentCache.Response.new(response, "cached")}
    end
  end

  defp validate(conn, request, response) do
    conn
    |> Client.run(
      request
      |> append_headers(response)
    )
    |> case do
      {:ok, %Response{status_code: 304, headers: headers}} ->
        # Remove content-type and content-length
        {
          :ok,
          response
          |> Map.put(
            :headers,
            headers
            |> Header.delete("content-type")
            |> Header.delete("content-length")
          )
          |> ContentCache.Response.new("cached")
        }

      {:ok, new_res} ->
        if is_the_same?(response, new_res) do
          {
            :ok,
            new_res
            |> ContentCache.Response.new("cached")
          }
        else
          {
            :ok,
            new_res
            |> ContentCache.Response.new("updated")
          }
        end

      error ->
        error
    end
  end

  defp append_headers(request, response) do
    request
    |> Map.put(
      :headers,
      request
      |> Map.get(:headers)
      |> Header.add(
        "if-modified-since",
        Header.get(
          response
          |> Map.get(:headers),
          "last-modified"
        )
      )
      |> Header.add(
        "if-none-match",
        Header.get(
          response
          |> Map.get(:headers),
          "etag"
        )
      )
    )
  end

  defp is_the_same?(old, new) do
    try do
      hash_string(old.body) == hash_string(new.body)
    rescue
      _ -> hash_string(Jason.encode!(old.body)) == hash_string(Jason.encode!(new.body))
    end
  end

  defp hash_string(string) do
    :crypto.hash(:sha256, string)
    |> Base.encode16()
  end
end
