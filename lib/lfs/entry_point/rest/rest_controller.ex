defmodule Lfs.EntryPoint.Rest.RestController do
  use Plug.Router
  use Plug.ErrorHandler
  require Logger
  alias Lfs.Usecase.LfsApi
  import Lfs.EntryPoint.Rest.HealthIndicator

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:multipart, :urlencoded, :json],
    pass: ["text/*", "application/*"],
    json_decoder: Poison
  )

  plug(:dispatch)


  get "/health" do
    health()
    |> build_response(conn)
  end

  post "/objects/batch" do
    IO.puts("/objects/batch post")
    {:ok, _, payload} = read_body(conn)
    IO.puts("------- Start batch ------")
    IO.inspect(payload)
    IO.puts("------- Response ------")
    case LfsApi.objects_batch(payload) do
      {:ok, response} -> %{status: 200, body: Poison.encode!(response)}
      _ -> %{status: 500, body: Poison.encode!(%{:status => "Error"})}
    end
    |> build_response(conn)
  end

  def read_multipart_put(conn, url, up_id) do
    ets_table = String.to_atom(Regex.replace(~r/.*\//, url, ""))

    upload_env =
      if up_id do
        up_id
      else
        IO.puts("Inicializando ==================================")
        :ets.new(ets_table, [:public, :set, :named_table])
        %{
          :upload_id => Lfs.Adapters.S3Adapter.create_multipart_upload("lab-git-lfs", url),
          :part => 0
        }
      end
    part=upload_env.part+1
    rcode =
      case read_body(conn) do
        {:more, data, _} ->
          IO.puts("more")
          IO.inspect(:crypto.hash(:md5, data)|> Base.encode16())

          :ets.insert(
            ets_table,
            {Lfs.Adapters.S3Adapter.upload_file_part(
               "lab-git-lfs",
               url,
               upload_env.upload_id,
               :ets.info(ets_table)[:size]+1,
               data
             )}
          )

          read_multipart_put(conn, url, upload_env)

        {:ok, data, _} ->
          IO.puts("ok")

          :ets.insert(
            ets_table,
            {Lfs.Adapters.S3Adapter.upload_file_part(
               "lab-git-lfs",
               url,
               upload_env.upload_id,
               :ets.info(ets_table)[:size]+1,
               data
             )}
          )
          IO.inspect(:ets.tab2list(ets_table))
          Lfs.Adapters.S3Adapter.complete_multipart_upload(
            "lab-git-lfs",
            url,
            upload_env.upload_id,
            Enum.sort(Enum.map(:ets.tab2list(ets_table), fn x -> {r}=x; r end))
          )
          #Enum.map(:ets.tab2list(ets_table), fn s ->  {id} = s id end)

          :ets.delete(ets_table)

        {:done, connx} ->
          IO.puts("done")
          data = read_body(conn)
      end
  end

  put _ do
    IO.puts("@@@@@@@@@@@@@@ put")
    url = conn.request_path
    read_multipart_put(conn, url, nil)
    %{status: 200, body: Poison.encode!(%{:status => "ok"})} |> build_response(conn)
  end

  post _ do
    IO.puts("@@@@@@@@@@@@@@ post")
    read_body(conn)
    health() |> build_response(conn)
    IO.puts("========= post")
  end

  get _ do
    health() |> build_response(conn)
  end

  def build_response(%{status: status, body: body}, conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  def build_response(response, conn) do
    build_response(%{status: 200, body: response}, conn)
  end

  def build_err_response(response, conn) do
    build_response(%{status: 500, body: response}, conn)
  end

  def print_json(data) do
    {:ok, json} = Poison.encode(data)
    IO.puts(json)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end

  def handle_errors(conn, %{kind: kind, reason: reason, stack: stack}) do
    Logger.error(
      "Error in rest entry-point kind: #{inspect(kind)} reason: #{inspect(reason)} stack: #{
        inspect(stack)
      }"
    )

    send_resp(conn, conn.status, "Internal Server Error")
  end
end
