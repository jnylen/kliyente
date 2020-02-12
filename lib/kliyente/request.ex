defmodule Kliyente.Request do
  @moduledoc false

  defstruct method: nil,
            path: nil,
            headers: [],
            body: nil,
            opts: [],
            previous_locations: []

  alias Kliyente.{Error, Request, Response, Cookie, Header}

  def call(
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

  defp append_headers(conn, headers),
    do: Cookie.add(Mint.HTTP.get_private(conn, :jar), headers) |> IO.inspect()

  ## TODO: Fix so you can follow redirect to another domain.
  defp follow_redirect(
         {:ok,
          %Response{conn: conn, request: request, headers: headers, status_code: status_code}}
       )
       when status_code > 300 and status_code < 400 do
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
end
