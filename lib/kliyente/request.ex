defmodule Kliyente.Request do
  @moduledoc false

  defstruct method: nil,
            path: nil,
            headers: [],
            body: nil,
            opts: [],
            previous_locations: []

  alias Kliyente.{ContentCache, Error, Request, Response, Cookie, Header}

  # INCOMING CALL
  def call(
        conn,
        %Request{opts: opts} = request
      ) do
    # Can be cached?
    if ContentCache.Request.cacheable?(request) and has_required_opts?(opts) do
      # SKIP?
      request
      |> cache_fetch()
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
    else
      conn
      |> run(request)
    end
  end

  # HTTP CALL
  defp run(
         conn,
         %Request{method: method, path: path, headers: headers, body: body, opts: _opts} = request
       ) do
    Mint.HTTP.request(conn, method, path, append_headers(conn, headers), body)
    |> case do
      {:ok, conn, _request_ref} ->
        Response.receive(conn, %Response{}, request, 5000)
        |> case do
          {:ok, response} ->
            {
              :ok,
              response
              |> Map.put(
                :conn,
                response
                |> Map.get(:conn)
                |> Mint.HTTP.put_private(:module, Mint.HTTP.get_private(conn, :module, nil))
                |> Mint.HTTP.put_private(:jar, Mint.HTTP.get_private(conn, :jar, Cookie.new()))
              )
              |> Cookie.update()
            }

          {:error, reason} ->
            {:error, %Error{reason: reason}}

          _ ->
            {:error, %Error{message: "unknown response from response"}}
        end

      {:error, _, reason} ->
        {:error, %Error{reason: reason}}

      {:error, reason} ->
        {:error, %Error{reason: reason}}

      _ ->
        {:error, %Error{message: "unknown response from request"}}
    end
    |> follow_redirect()
  end

  defp run_and_store(conn, request) do
    with {:ok, response} <- run(conn, request) do
      ContentCache.File.store(request, response)
    end
  end

  # Fetch
  defp cache_fetch(request) do
    with {:ok, response} <- ContentCache.File.get(request) do
      {:ok, ContentCache.Response.new(response, "cached")}
    end
  end

  defp has_required_opts?(opts) do
    # if Keyword.get(opts, :file_name, false) and Keyword.get(opts, :folder_name, false) do
    #  true
    # else
    #  false
    # end
    true
  end

  defp append_headers(conn, headers),
    do: Cookie.add(Mint.HTTP.get_private(conn, :jar), headers)

  ## TODO: Fix so you can follow redirect to another domain.
  defp follow_redirect(
         {:ok,
          %Response{conn: conn, request: request, headers: headers, status_code: status_code}}
       )
       when status_code in [301, 302, 303, 307, 308] do
    cond do
      Enum.empty?(Header.get_values(headers, "location")) ->
        {:error, %Error{message: "redirect found but no location specified"}}

      Enum.count(Header.get_values(headers, "location")) > 1 ->
        {:error, %Error{message: "redirect found but too many locations specified"}}

      true ->
        Request.call(
          conn,
          request
          |> Map.put(:body, nil)
          |> Map.put(:method, "GET")
          |> Map.put(:path, Header.get_values(headers, "location") |> List.first())
          |> Map.put(
            :headers,
            Map.get(request, :headers, []) ++ [{"referer", Map.get(request, :path)}]
          )
          |> Map.put(
            :previous_locations,
            Map.get(request, :previous_locations, []) ++ [Map.get(request, :path)]
          )
        )
    end
  end

  defp follow_redirect(response), do: response

  defp validate(conn, request, response) do
    conn
    |> run(
      request
      |> append_valid_headers(response)
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

  defp append_valid_headers(request, response) do
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
