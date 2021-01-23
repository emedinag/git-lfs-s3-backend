defmodule Lfs.Usecase.LfsApi do
  @moduledoc false
import Lfs.Utils.DataTypeUtils
  def objects_batch(payload) do
    headers=normalize(payload.req_headers)
    operation=normalize(payload.params)
    case operation do
      %{:objects=> objects,:operation=> "upload",:ref => ref,:transfers => transfers} ->  %{
        :transfer => "basic",
        :objects => Enum.map(objects, &generate_upload_object/1)
      }
      _ -> {:err}
    end |> Poison.encode!()
  end

defp generate_upload_object(_object =%{oid: oid, size: size}) do
    %{
      :oid => oid,
      :size => size,
      :authenticated => true,
      :actions => %{
        :upload => %{
          :href => "http://localhost:8083/"<>String.slice(oid, 0..1)<>"/"<>oid,
          :header => %{
            "Authorization": "Basic ..."
          },
          :expires_in => 86400
        }
      }
    }
end
end
