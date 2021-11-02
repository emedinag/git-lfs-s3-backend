defmodule Lfs.Utils.RestClient do
  def doGet(url), do: doGet(url, [])
  def doGet(url, headers) do
    case :hackney.get(url, headers) do
      {:ok, code, headers, ref}  when code <=299 -> {_,body}= :hackney.body(ref)
                                  IO.inspect(code)
                                  if evaluateRestContentType(headers) do
                                      {:ok, code, headers, Poison.decode!(body)}
                                  else
                                      {:ok, code, headers, body}
                                  end
      {:ok, code, headers, ref}  when code > 300 -> {:error}
      _other -> {:error}
    end
  end

  defp evaluateRestContentType(headers) do
    Enum.find_value(headers, fn x -> case x do {"Content-Type", tag} -> String.contains?(tag, "application/json") ;  _ -> nil  end end)
  end


end
