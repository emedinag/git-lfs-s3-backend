defmodule Lfs.Usecase.LfsApi do
  @moduledoc false
  import Lfs.Utils.DataTypeUtils
  alias Lfs.Adapters.S3Adapter

  @spec objects_batch(atom | %{:params => any, :req_headers => any, optional(any) => any}) ::
          {:err} | {:ok, %{objects: list, transfer: <<_::40>>}}
  def objects_batch(payload) do
    headers = normalize(payload.req_headers)
    operation = normalize(payload.params)
    case Enum.find_value(headers, fn x -> case x do {"authorization", auth} -> String.slice(auth,  6..-1); _ -> nil  end end) do
      b64Value -> case operation do
                  %{:objects => objects, :operation => "upload", :ref => _ref, :transfers => _transfers} ->  {:ok,
                    %{
                      :transfer => "basic",
                      :objects => Enum.map(objects, &generate_upload_object(b64Value, &1))
                    } }
                    %{:objects => objects, :operation => "download", :ref => _ref, :transfers => _transfers} -> {:ok,
                      %{
                        :transfer => "basic",
                        :objects => Enum.map(objects, &generate_download_object/1)
                      }
                    }
                  _ ->
                    {:err}
                end
      nil -> {:err}
  end
end

  defp generate_upload_object(b64Value, _object = %{oid: oid, size: size}) do
    %{
      :oid => oid,
      :size => size,
      :authenticated => true,
      :actions => %{
        :upload => %{
          :href => "http://localhost:8083/" <> String.slice(oid, 0..1) <> "/"<> String.slice(oid, 2..3) <> "/" <> oid,
          :header => %{
            Authorization: "Basic "<> b64Value
          },
          :expires_in => 86400
        }
      }
    }
  end

  defp generate_download_object(_object = %{oid: oid, size: size}) do
    %{
      :oid => oid,
      :size => size,
      :authenticated => true,
      :actions => %{
        :upload => %{
          :href => S3Adapter.generateSignedGetUrl("lab-git-lfs", "/" <> String.slice(oid, 0..1) <> "/"<> String.slice(oid, 2..3) <>"/" <> oid),
          :header => %{},
          :expires_in => 86400
        }
      }
    }
  end



  def uploadObject(data, url) do
    S3Adapter.upload_file("lab-git-lfs", data, url)
  end
end
