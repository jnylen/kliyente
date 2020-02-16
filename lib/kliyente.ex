defmodule Kliyente do
  @moduledoc """
  Documentation for Kliyente.
  """

  alias Kliyente.{Client, Cookie, Error, Request}

  @doc """
    `open/1` takes an already closed connection and tries to open it again.
  """
  def open({:ok, %{conn: conn, opts: opts}} = tuple) do
    if alive?(tuple) do
      tuple
    else
      open(
        conn.host,
        opts,
        conn
      )
    end
  end

  @doc """
    `open/4` opens a connection a domain and create a cookie jar.

    ** Examples: **

      > Kliyente.open("httpbin.org")
      {:ok,
        %Kliyente.Client{
          conn: %Mint.HTTP1{
            buffer: "",
            host: "httpbin.org",
            mode: :active,
            port: 80,
            private: %{jar: #PID<_>, module: nil},
            request: nil,
            requests: {[], []},
            scheme_as_string: "http",
            socket: #Port<_>,
            state: :open,
            transport: Mint.Core.Transport.TCP
          }
        }
      }
  """
  def open(domain, opts \\ [], old_conn \\ nil) do
    Mint.HTTP.connect(
      if(Keyword.get(opts, :ssl, false), do: :https, else: :http),
      domain,
      if(Keyword.get(opts, :ssl, false), do: 443, else: 80),
      ssl_opts?(Keyword.get(opts, :ssl, false), opts)
    )
    |> case do
      {:ok, conn} ->
        {:ok,
         %Client{
           opts: opts,
           conn:
             conn
             |> Mint.HTTP.put_private(
               :module,
               get_old_conf?(:module, old_conn) || Keyword.get(opts, :module)
             )
             |> Mint.HTTP.put_private(:jar, get_old_conf?(:jar, old_conn))
         }}

      val ->
        val
    end
  end

  def get(client_tuple, path, headers \\ [])

  def get({:error, _} = error, _path, _headers), do: error

  def get({:ok, %{conn: _conn}} = tuple, path, headers),
    do: call(tuple, %Request{method: "GET", path: path, headers: headers})

  def post(client_tuple, path, body, headers \\ [])
  def post({:error, _} = error, _path, _body, _headers), do: error

  def post({:ok, %{conn: _conn}} = tuple, path, body, headers),
    do: call(tuple, %Request{method: "POST", path: path, headers: headers, body: body})

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

  defp call(tuple, request) do
    tuple
    |> open()
    |> case do
      {:ok, %{conn: conn}} ->
        Request.call(conn, request)

      _val ->
        {:error, %Error{reason: "not correct format in call"}}
    end
  end

  defp get_old_conf?(:module, nil), do: nil

  defp get_old_conf?(:module, conn) do
    conn
    |> Mint.HTTP.get_private(:module)
  end

  defp get_old_conf?(:jar, nil), do: Cookie.new()

  defp get_old_conf?(:jar, conn) do
    conn
    |> Mint.HTTP.get_private(:jar, Cookie.new())
  end

  defp ssl_opts?(true, opts) do
    opts
    |> Keyword.get(:client, [])
    |> Keyword.put_new(:transfer_opts, ciphers: :ssl.cipher_suites(:default, :"tlsv1.2"))
  end

  defp ssl_opts?(_, opts), do: opts |> Keyword.get(:client, [])
end
