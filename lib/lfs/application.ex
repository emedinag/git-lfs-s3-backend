defmodule Lfs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias Lfs.Config.{AppConfig, ConfigHolder}
  alias Lfs.EntryPoint.Rest.RestController
  use Application
  require Logger

  def start(_type, _args) do
    config = AppConfig.load_config()
    in_test? = Application.fetch_env(:lfs, :in_test)

    children = with_plug_server(config) ++ application_children(in_test?)

    opts = [strategy: :one_for_one, name: Lfs.Supervisor]
    h_opts = [{:timeout, 190_000}, {:max_connections, 6000}]
    :ok = :hackney_pool.start_pool(:app_pool, h_opts)

    Supervisor.start_link(children, opts)
  end

  defp with_plug_server(%AppConfig{enable_server: true, http_port: port}) do
    Logger.info("Configure Http server in port: #{inspect(port)}")

    [
      {
        Plug.Cowboy,
        scheme: :http,
        plug: RestController,
        options: [
          port: port
        ]
      }
    ]
  end

  defp with_plug_server(%AppConfig{enable_server: false}), do: []

  def application_children({:ok, true} = _test_env) do
    [
      {ConfigHolder, AppConfig.load_config()},
      {Task.Supervisor, name: Lfs.TaskSupervisor}
    ]
  end

  def application_children(_other_env) do
    [
      {ConfigHolder, AppConfig.load_config()},
      {Task.Supervisor, name: Lfs.TaskSupervisor}
      # {Redix, {Application.get_env(:ms_auth_ex, :redis_url), [name: :redix]}},
      # {SecretManagerAdapter, []},
      # {RequestCipherHolder, []},
    ]
  end
end
