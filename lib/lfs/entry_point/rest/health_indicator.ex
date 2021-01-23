defmodule Lfs.EntryPoint.Rest.HealthIndicator do
    require Logger
    #alias MsAuthEx.Adapters.Redis.RedisRepositoryAdapter
    #alias MsAuthEx.Adapters.Dynamo.DynamoAdapter
  
    #def health() do
    #  with {:ok, _} <- RedisRepositoryAdapter.health(),
    #       {:ok, _} <- DynamoAdapter.health()
    #    do
    #    "UP"
    #  else
    #    error -> Logger.error "Health check error: #{inspect(error)}"
    #             %{status: 503, body: "DOWN"}
    #  end
    #end
   
    def health() do
        "UP"
    end
  end
  