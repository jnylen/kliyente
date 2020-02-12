defmodule Kliyente.Response do
  @moduledoc false

  defstruct request: nil,
            status_code: nil,
            headers: [],
            cookies: [],
            body: "",
            complete: false,
            conn: nil

  alias Kliyente.{Request, Error, Header, Cookie}

  # Cache the result etc
  defp parse_response(response) do
  end

  defp time, do: System.monotonic_time(:millisecond)

  @doc false
  def receive(conn, response, %Request{} = request, timeout) do
    start_time = time()

    receive do
      {:tcp, _, _} = msg -> handle_msg(conn, response, timeout, msg, start_time, request)
      {:ssl, _, _} = msg -> handle_msg(conn, response, timeout, msg, start_time, request)
    after
      timeout -> {:error, %Error{reason: :timeout}}
    end
  end

  defp handle_msg(conn, response, timeout, msg, start_time, request) do
    new_timeout = fn ->
      time_elapsed = time() - start_time

      case timeout - time_elapsed do
        x when x < 0 -> 0
        x -> x
      end
    end

    case Mint.HTTP.stream(conn, msg) do
      {:ok, mint_conn, resps} ->
        conn = mint_conn
        response = apply_resps(response, resps)

        if response.complete do
          {
            :ok,
            response
            |> Map.put(
              :conn,
              mint_conn
            )
            |> Map.put(:request, request)
          }
        else
          receive(conn, response, request, new_timeout.())
        end

      {:error, _, e, _} ->
        {:error, %Error{reason: e}}

      :unknown ->
        receive(conn, response, request, new_timeout.())
    end
  end

  defp apply_resps(response, []), do: response

  defp apply_resps(response, [mint_resp | rest]) do
    apply_resp(response, mint_resp) |> apply_resps(rest)
  end

  defp apply_resp(response, {:status, _request_ref, status_code}) do
    %{response | status_code: status_code}
  end

  defp apply_resp(response, {:headers, _request_ref, headers}) do
    %{response | headers: headers}
  end

  defp apply_resp(response, {:data, _request_ref, chunk}) do
    %{response | body: [response.body | [chunk]]}
  end

  defp apply_resp(response, {:done, _request_ref}) do
    %{response | complete: true, body: :erlang.iolist_to_binary(response.body)}
  end
end
