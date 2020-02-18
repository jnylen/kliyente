defmodule Kliyente.Client do
  defstruct conn: nil, opts: []

  alias Kliyente.{Response, Request, Error, Cookie, Header}

  def run(
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
                |> Mint.HTTP.put_private(:opts, Mint.HTTP.get_private(conn, :opts))
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
    do: Cookie.add(Mint.HTTP.get_private(conn, :jar), headers)

  defp follow_redirect(
         {:ok,
          %Response{conn: conn, request: request, headers: headers, status_code: status_code}} =
           tuple
       )
       when status_code in [301, 302, 303, 307, 308] do
    cond do
      Enum.empty?(Header.get_values(headers, "location")) ->
        {:error, %Error{message: "redirect found but no location specified"}}

      Enum.count(Header.get_values(headers, "location")) > 1 ->
        {:error, %Error{message: "redirect found but too many locations specified"}}

      true ->
        headers
        |> Header.get_values("location")
        |> List.first()
        |> URI.parse()
        |> case do
          # Same connection
          %URI{
            host: nil,
            path: path
          } ->
            Request.call(
              conn,
              request
              |> Map.put(:body, nil)
              |> Map.put(:method, "GET")
              |> Map.put(:path, path)
              |> Map.put(
                :headers,
                Map.get(request, :headers, []) ++ [{"referer", Map.get(request, :path)}]
              )
              |> Map.put(
                :previous_locations,
                Map.get(request, :previous_locations, []) ++ [Map.get(request, :path)]
              )
            )

          %URI{path: path, query: query} = uri ->
            # Create a new conn
            Kliyente.close(tuple)

            {:ok, %Kliyente.Client{conn: new_conn}} =
              Kliyente.open(uri.host, ssl: if(uri.scheme == "https", do: true, else: false))

            real_path = %URI{path: path, query: query} |> URI.to_string()

            Request.call(
              new_conn,
              request
              |> Map.put(:body, nil)
              |> Map.put(:method, "GET")
              |> Map.put(:path, real_path)
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
  end

  defp follow_redirect(response), do: response
end
