defmodule Lfs.Config.ConfigHolder do
    use GenServer
    alias Lfs.Config.AppConfig
  
    def start_link(conf = %AppConfig{}), do: GenServer.start_link(__MODULE__, conf, name: __MODULE__)
  
    @impl true
    def init(conf) do
      :ets.new(:app_conf, [:named_table, read_concurrency: true])
      :ets.insert(:app_conf, {:conf, conf})
      {:ok, nil}
    end
  
    def conf do
      [{_, config}] = :ets.lookup(:app_conf, :conf)
      config
    end
  
  end
  