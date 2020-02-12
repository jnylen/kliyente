defmodule Kliyente.Cookie do
  alias Kliyente.{Cookie, Response, Header, Error}

  def new do
    CookieJar.new()
    |> case do
      {:ok, jar} -> jar
      _ -> nil
    end
  end

  def peek(%Response{conn: conn}), do: peek(conn)
  def peek(conn), do: CookieJar.peek(Mint.HTTP.get_private(conn, :jar, %{}))

  def add(jar, nil), do: add(jar, [])

  def add(jar, headers) do
    jar_cookies = CookieJar.label(jar)

    headers
    |> Enum.into(%{})
    |> Map.update("cookie", jar_cookies, fn user_cookies ->
      "#{user_cookies}; #{jar_cookies}"
    end)
    |> Enum.into([])
  end

  def update(%Response{conn: conn, headers: headers} = response) do
    do_update(Mint.HTTP.get_private(conn, :jar), headers)

    response
    |> Map.put(:cookies, Cookie.peek(conn))
  end

  def update(%Error{} = error), do: error

  defp do_update(jar, headers) when is_list(headers) do
    response_cookies = Header.get_values(headers, "set-cookie")

    cookies =
      Enum.reduce(response_cookies, %{}, fn cookie, cookies ->
        [key_value_string | _rest] = String.split(cookie, "; ")
        [key, value] = String.split(key_value_string, "=", parts: 2)
        Map.put(cookies, key, value)
      end)

    CookieJar.pour(jar, cookies)
  end
end
