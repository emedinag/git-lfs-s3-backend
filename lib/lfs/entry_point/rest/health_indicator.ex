defmodule Lfs.EntryPoint.Rest.HealthIndicator do
  require Logger



  def health() do
    Poison.encode!(%{:status=>"ok"})
  end
end
