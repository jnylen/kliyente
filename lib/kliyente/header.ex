defmodule Kliyente.Header do
  def get(headers, name) do
    case get_values(headers, name) do
      [] -> nil
      values -> values |> Enum.join(",")
    end
  end

  def get_values(headers, name) do
    get_values(headers, String.downcase(name), [])
  end

  defp get_values([], _name, values), do: values

  defp get_values([{key, value} | rest], name, values) do
    new_values =
      if String.downcase(key) == name do
        values ++ [value]
      else
        values
      end

    get_values(rest, name, new_values)
  end

  def auth_header(username, password) do
    auth64 = "#{username}:#{password}" |> Base.encode64()
    {"authorization", "Basic #{auth64}"}
  end

  def keys(headers) do
    keys(headers, [])
  end

  defp keys([], names), do: Enum.reverse(names)

  defp keys([{name, _value} | rest], names) do
    name = String.downcase(name)

    if name in names do
      keys(rest, names)
    else
      keys(rest, [name | names])
    end
  end

  def normalize(headers, joiner \\ ",") do
    headers_map =
      Enum.reduce(headers, %{}, fn {name, value}, acc ->
        name = String.downcase(name)
        values = Map.get(acc, name, [])
        Map.put(acc, name, values ++ [value])
      end)

    headers
    |> keys
    |> Enum.map(fn name ->
      {name, Map.get(headers_map, name) |> Enum.join(joiner)}
    end)
  end
end
