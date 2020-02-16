defmodule Kliyente.ContentCache.File do
  alias Calendar.DateTime, as: CalDT
  alias Kliyente.ContentCache.Response
  alias Kliyente.{Header, Request}

  defp storage(%Request{opts: opts}), do: Keyword.get(opts, :folder_name)
  defp file_name(%Request{opts: opts}), do: Keyword.get(opts, :file_name)
  defp file_path(request), do: Path.join([storage(request), file_name(request)])

  def put(request, response) do
    request
    |> file_path()
    |> File.write!(
      response
      |> Map.put(:conn, nil)
      |> encode()
    )
  end

  def get(request) do
    request
    |> file_path()
    |> File.exists?()
    |> case do
      true ->
        request
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
    |> file_path()
    |> File.rm!()
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
