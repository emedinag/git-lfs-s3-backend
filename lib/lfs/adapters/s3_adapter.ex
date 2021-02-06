defmodule Lfs.Adapters.S3Adapter do
  use GenServer
  alias Lfs.Config.ConfigHolder
  alias Lfs.Utils.DataTypeUtils

  def start_link(async_init) do
    GenServer.start_link(__MODULE__, async_init, name: __MODULE__)
  end

  def upload_file(bucket, data, path) do
    ExAws.S3.put_object(bucket, path, data)
    |> ExAws.request!()
    |> case do
      %{:body => _body, :headers => _headers, :status_code => 200} ->
        %{:status => 200, :body => Poison.encode!(["ok"])}

      no_expected ->
        {:error, no_expected}
    end
  end

  def upload_file_part(bucket, path, up_id, part_number, data) do
    ExAws.S3.upload_part(bucket, path, up_id, part_number, data) |> ExAws.request!()
    |> case do
      %{:body => _body, :headers => headers, :status_code => 200} ->
        etag=Enum.find_value(headers, fn x -> case x do {"ETag", tag} -> tag |> Poison.decode!(); _ -> nil  end end)
        {part_number, etag}

      no_expected ->
        {:error, no_expected}
    end
  end

  def complete_multipart_upload(bucket, path, up_id, parts) do
    %{:body => _body, :headers => headers, :status_code => 200} =
      ExAws.S3.complete_multipart_upload(bucket, path, up_id, parts)
      |> ExAws.request!()

    Enum.find_value(headers, fn x ->
      case x do
        {"ETag", tag} -> tag |> Poison.decode!()
        _ -> nil
      end
    end)
  end

  def create_multipart_upload(bucket, path) do
    resp = ExAws.S3.initiate_multipart_upload(bucket, path) |> ExAws.request!()
    resp.body.upload_id
  end

  def generateSignedGetUrl(bucket, path) do
    #query_params = [{"ContentType", mime_type}, {"ACL", "public-read"}]
    query_params = [{"ACL", "public-read"}]
    presign_options = [query_params: query_params]
    {:ok, presigned_url} = ExAws.Config.new(:s3)
        |> ExAws.S3.presigned_url(:get, bucket, path, presign_options)
    presigned_url
  end
end
