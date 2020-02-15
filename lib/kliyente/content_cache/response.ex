defmodule Kliyente.ContentCache.Response do
  alias Kliyente.{Response, Header}

  defp temp_min_modified, do: 3600

  def new(response, cache_status) do
    response
    |> append_headers(cache_status)
  end

  defp append_headers(%{headers: headers} = response, cache_status) do
    response
    |> Map.put(
      :headers,
      headers
      |> Header.delete("x-cache-status")
      |> Header.add("x-cache-status", cache_status)
    )
  end

  @cacheable_status [200, 203, 300, 301, 302, 307, 404, 410]
  def cacheable?(%Response{status_code: status}) when status in @cacheable_status,
    do: true

  def cacheable?(_), do: false

  def fresh?(%Response{} = response) do
    ttl(response) > 0
  end

  def check?(%Response{} = response) do
    cache_modified(response) < temp_min_modified()
  end

  defp cache_modified(%Response{headers: headers}) do
    with header when not is_nil(header) <- Header.get(headers, "x-cache-lastupdated"),
         {:ok, date} <- Calendar.DateTime.Parse.httpdate(header),
         {:ok, seconds, _, :after} <-
           Calendar.DateTime.diff(DateTime.utc_now(), date) do
      seconds
    else
      _ -> 0
    end
  end

  defp ttl(%Response{} = response) do
    with {:ok, max_age} <- max_age(response),
         {:ok, age} <- age(response) do
      max_age - age
    else
      _ -> 0
    end
  end

  defp max_age(%Response{headers: headers} = response) do
    with nil <- Header.get(headers, "s-max-age") |> int(),
         nil <- Header.get(headers, "max-age") |> int() do
      expires(response)
    else
      max when is_integer(max) -> {:ok, max}
    end
  end

  defp expires(%Response{headers: headers}) do
    with header when not is_nil(header) <- Header.get(headers, "expires"),
         {:ok, date} <- Calendar.DateTime.Parse.httpdate(header),
         {:ok, seconds, _, :after} <- Calendar.DateTime.diff(date, DateTime.utc_now()) do
      {:ok, seconds}
    else
      _ -> :error
    end
  end

  defp age(%Response{} = response) do
    age_by_age_header(response)
    # with :error <- age_by_age_header(response) do
    #   age_by_date_header(response)
    # end
  end

  defp age_by_age_header(%Response{headers: headers}) do
    with bin when not is_nil(bin) <- Header.get(headers, "age"),
         {age, ""} <- Integer.parse(bin) do
      {:ok, age}
    else
      _ -> :error
    end
  end

  defp age_by_date_header(%Response{headers: headers}) do
    with bin when not is_nil(bin) <- Header.get(headers, "date"),
         {:ok, date} <- Calendar.DateTime.Parse.httpdate(bin),
         {:ok, seconds, _, :after} <- Calendar.DateTime.diff(DateTime.utc_now(), date) do
      {:ok, seconds}
    else
      _ -> :error
    end
  end

  defp int(nil), do: nil

  defp int(bin) do
    case Integer.parse(bin) do
      {int, ""} -> int
      _ -> nil
    end
  end
end
