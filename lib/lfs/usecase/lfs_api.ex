defmodule Lfs.Usecase.LfsApi do
  @moduledoc false
  import Lfs.Utils.DataTypeUtils
  alias Lfs.Adapters.S3Adapter

  def objects_batch(payload) do
    headers = normalize(payload.req_headers)
    operation = normalize(payload.params)

    case operation do
      %{:objects => objects, :operation => "upload", :ref => _ref, :transfers => _transfers} ->  {:ok,
        %{
          :transfer => "basic",
          :objects => Enum.map(objects, &generate_upload_object/1)
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
  end

  defp generate_upload_object(_object = %{oid: oid, size: size}) do
    %{
      :oid => oid,
      :size => size,
      :authenticated => true,
      :actions => %{
        :upload => %{
          :href => "http://localhost:8083/" <> String.slice(oid, 0..1) <> "/" <> oid,
          :header => %{
            Authorization: "Basic ..."
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
          :href => S3Adapter.generateSignedGetUrl("lab-git-lfs", "/" <> String.slice(oid, 0..1) <> "/" <> oid),
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
