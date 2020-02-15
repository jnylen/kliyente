defmodule Kliyente.ContentCache.File do
  alias Calendar.DateTime, as: CalDT
  alias Kliyente.ContentCache.Response
  alias Kliyente.Header

  defp temp_storage, do: "/tmp/kliyente/"
  defp file_path(key), do: Path.join([temp_storage(), key])

  def put(request, response) do
    request
    |> Map.get(:path)
    |> hash_string()
    |> file_path()
    |> File.write!(
      response
      |> Map.put(:conn, nil)
      |> encode()
    )
  end

  def get(request) do
    request
    |> Map.get(:path)
    |> hash_string()
    |> file_path()
    |> File.exists?()
    |> case do
      true ->
        request
        |> Map.get(:path)
        |> hash_string()
        |> file_path()
        |> File.read!()
        |> decode()
        |> case do
          nil -> {:error, "not found"}
          data -> {:ok, data}
        end

      _ ->
        {:error, "not found"}
    end
  end

  def delete(request) do
    request
    |> Map.get(:path)
    |> hash_string()
    |> file_path()
    |> File.rm!()
  end

  defp hash_string(string) do
    :crypto.hash(:sha256, string)
    |> Base.encode16()
  end

  def store(request, response) do
    if Response.cacheable?(response) do
      new_response =
        response
        |> ensure_no_status_header()
        |> ensure_date_header()

      put(
        request,
        new_response
      )

      {:ok, Response.new(new_response, "fresh")}
    else
      {:ok, response}
    end
  end

  defp ensure_no_status_header(%Kliyente.Response{headers: headers} = response) do
    response
    |> Map.put(
      :headers,
      headers
      |> Header.delete("x-cache-status")
    )
  end

  defp ensure_date_header(%Kliyente.Response{headers: headers} = response) do
    headers
    |> Header.get("x-cache-lastupdated")
    |> case do
      nil ->
        response
        |> Map.put(
          :headers,
          headers
          |> Header.add("x-cache-lastupdated", CalDT.Format.httpdate(DateTime.utc_now()))
        )

      _ ->
        response
    end
  end

  defp encode(data), do: :erlang.term_to_binary(data)
  defp decode(nil), do: nil
  defp decode(bin), do: :erlang.binary_to_term(bin, [:safe])
end
