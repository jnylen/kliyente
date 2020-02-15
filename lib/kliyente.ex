defmodule Kliyente do
  @moduledoc """
  Documentation for Kliyente.
  """

  alias Kliyente.{Header, Client, Error, Cookie, Request}

  def open({:ok, %{conn: conn} = struct}) do
    if alive?(conn) do
      {:ok, struct}
    else
      open(
        conn.host,
        Mint.HTTP.get_private(conn, :module),
        if(conn.schema_as_string == "http", do: false, else: true),
        conn
      )
    end
  end

  def open(domain, module \\ nil, ssl \\ false, old_conn \\ nil) do
    Mint.HTTP.connect(if(ssl, do: :https, else: :http), domain, if(ssl, do: 443, else: 80))
    |> case do
      {:ok, conn} ->
        {:ok,
         %Client{
           conn:
             conn
             |> Mint.HTTP.put_private(:module, module)
             |> Mint.HTTP.put_private(:jar, get_old_jar?(old_conn))
         }}

      val ->
        val
    end
  end

  @spec get({:error, any} | {:ok, %{conn: any}}, any, any) :: {:error, any} | {:ok, any}
  def get(client_tuple, path, headers \\ [])

  def get({:error, _} = error, _path, _headers), do: error

  def get({:ok, %{conn: conn}}, path, headers),
    do: Request.call(conn, %Request{method: "GET", path: path, headers: headers})

  def post(client_tuple, path, body, headers \\ [])
  def post({:error, _} = error, _path, _body, _headers), do: error

  def post({:ok, struct}, path, body, headers) do
  end

  def alive?({:ok, %{conn: conn}}) do
    conn
    |> Mint.HTTP.open?()
  end

  def alive?(_), do: false

  def close({:ok, %{conn: conn}}) do
    # Close jar
    CookieJar.stop(Mint.HTTP.get_private(conn, :jar, nil))

    # Close Mint
    Mint.HTTP.close(conn)
  end

  defp get_old_jar?(nil), do: Cookie.new()

  defp get_old_jar?(conn) do
    conn
    |> Mint.HTTP.get_private(:jar, Cookie.new())
  end
end
