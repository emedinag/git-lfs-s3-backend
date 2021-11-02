defmodule Lfs.Usecase.AzdSecurityFilter do
  use GenServer
  alias Lfs.Utils.RestClient
  alias Lfs.Utils.DataTypeUtils

  @flush_interval_s 60*10
  @max_buffer_size 10_000

  # Client APIs

  def queryToken(sha_token) do
    initVstsTokenCache()
    case :ets.match_object(:vsts_token_cache, {sha_token,:_}) do
      [{_sha, timer}] -> if  Time.diff(Time.utc_now(), timer ) <= @flush_interval_s do
        IO.puts("cached")
        :ok
      else
        :error
      end
      [] -> :error
      _ -> :error
    end
  end

  defp appendToken(sha_token) do
    :ets.insert(:vsts_token_cache, {sha_token, Time.utc_now()})
  end

  defp initVstsTokenCache() do
    case :ets.info(:vsts_token_cache) do
      :undefined -> :ets.new(:vsts_token_cache, [:public, :set, :named_table])
      _ -> :ok
    end
  end

  def validateReadRepo(repoName, headers) do
    case Enum.find_value(headers, fn x -> case x do {"authorization", auth} -> String.slice(auth,  6..-1) |> Fast64.decode64(); _ -> nil  end end) do
      b64Value -> h64= :crypto.hash(:sha, b64Value)|> Base.encode16() |> String.downcase()
      case queryToken(h64) do
        :ok -> :ok
        :error -> case  RestClient.doGet(System.get_env("REPO_API"), headers) do
          {:ok, _code, _h, body} -> if Enum.filter(DataTypeUtils.normalize(body["value"]), fn  e -> String.downcase(e.name) ==  String.downcase("AW000000_DEMO_AUDITORIA")  end ) do
                                        appendToken(h64)
                                        :ok
                                    else
                                      :error
                                    end
          {:error} -> :error
        end
      end
      nil -> :error
    end
  end
end

