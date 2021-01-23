defmodule Lfs.EntryPoint.Rest.RestController do
    use Plug.Router
    use Plug.ErrorHandler
    require Logger
    alias  Lfs.Usecase.LfsApi
    #alias MsAuthEx.Utils.DataTypeUtils
    #import MsAuthEx.UseCase.AuthenticationUseCase
    #import MsAuthEx.UseCase.PublicKeyUseCase
    #import MsAuthEx.UseCase.CloseSessionUseCase
    #import MsAuthEx.UseCase.RefreshTokenUseCase
    #import MsAuthEx.UseCase.BiometricUseCase
    #import MsAuthEx.UseCase.QueryUseCase
    import Lfs.EntryPoint.Rest.HealthIndicator

    plug :match
    plug Plug.Parsers, parsers: [:urlencoded, :json], pass: ["text/*"], json_decoder: Poison
    plug :dispatch

    #post "/authentication" do
    #  DataTypeUtils.normalize(conn.body_params)
    #  |> authenticate(conn.req_headers)
    #  |> build_response(conn)
    #end

    #get "/publickey" do
    #  public_key()
    #  |> build_response(conn)
    #end



    get "/health" do
      health()
      |> build_response(conn)
    end

    post "/objects/batch" do
      IO.puts("/objects/batch post")
      {:ok, _, payload} =read_body(conn)
      LfsApi.objects_batch(payload) |> build_response(conn)
    end

    put _ do
      IO.puts("@@@@@@@@@@@@@@ put")
        IO.inspect(read_body(conn))
        health() |> build_err_response(IO.inspect(conn))
    end

    post _ do
        IO.puts("@@@@@@@@@@@@@@ post")
        IO.inspect(read_body(conn))
        health() |> build_err_response(conn)
        IO.puts("========= post")
    end

    get _ do
        health() |> build_err_response(IO.inspect(conn))
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
      Logger.error "Error in rest entry-point kind: #{inspect(kind)} reason: #{inspect(reason)} stack: #{inspect(stack)}"
      send_resp(conn, conn.status, "Internal Server Error")
    end

  end
