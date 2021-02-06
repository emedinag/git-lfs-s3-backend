defmodule Lfs.Utils.DataTypeUtils do
  def normalize(value = %{__struct__: _}), do: value

  def normalize(map = %{}) do
    Map.to_list(map)
    |> Enum.map(fn {key, value} -> {String.to_atom(key), normalize(value)} end)
    |> Enum.into(%{})
  end

  def normalize(value) when is_list(value), do: Enum.map(value, &normalize/1)
  def normalize(value), do: value

  def extract_header(headers, name) when is_list(headers) do
    out = Enum.filter(headers, create_evaluator(name))

    case out do
      [{_, value} | _] -> {:ok, value}
      _ -> {:error, "not found"}
    end
  end

  def extract_header(_headers, _ame) do
    {:error, "headers is not a list"}
  end

  defp create_evaluator(name) do
    fn
      {^name, _} -> true
      _ -> false
    end
  end
end
