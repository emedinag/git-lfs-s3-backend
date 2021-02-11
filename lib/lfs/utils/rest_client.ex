defmodule Lfs.Utils.RestClient do
  def doGet(url), do: doGet(url, [])
  def doGet(url, headers) do
    case :hackney.get(url, headers) do
      {:ok, code, headers, ref} -> {_,body}= :hackney.body(ref)
      if evaluateRestContentType(headers) do
          {:ok, code, headers, Poison.decode!(body)}
      else
          {:ok, code, headers, body}
      end
      _other -> {:err}
    end
  end

  defp evaluateRestContentType(headers) do
    Enum.find_value(headers, fn x -> case x do {"Content-Type", tag} -> String.contains?(tag, "application/json") ;  _ -> nil  end end)
  end

  
end
