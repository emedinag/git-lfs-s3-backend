defmodule Lfs.Config.AppConfig do
  defstruct [
    :http_port,
    :enable_server,
    :region,
    :redis_url,
    :dynamo_lock_table
  ]

  def load_config do
    %__MODULE__{
      http_port: load(:http_port),
      enable_server: load(:enable_server),
      region: load(:region),
      dynamo_lock_table: load(:dynamo_lock_table)
    }
  end

  defp load(prop_name), do: Application.fetch_env!(:lfs, prop_name)
end
