defmodule Lfs.EntryPoint.Rest.RestController do
  use Plug.Router
  use Plug.ErrorHandler

  require Logger
  alias Lfs.Usecase.LfsApi
  import Lfs.EntryPoint.Rest.HealthIndicator
  alias Lfs.Usecase.AzdSecurityFilter
  require OpenTelemetry.Tracer, as: Tracer
  alias OpenTelemetry.Span


  defmodule Propagation do
    @moduledoc """
    Adds OpenTelemetry context propagation headers to the Plug response.

    ### WARNING

    These context headers are potentially dangerous to expose to third-parties.
    W3C recommends against including them except in cases where both client and
    server participate in the trace.

    See https://www.w3.org/TR/trace-context/#other-risks for more information.
    """

    @behaviour Plug
    import Plug.Conn, only: [register_before_send: 2, merge_resp_headers: 2]

    @impl true
    def init(opts) do
      opts
    end

    @impl true
    def call(conn, _opts) do
      register_before_send(conn, &merge_resp_headers(&1, :otel_propagator.text_map_inject([])))
    end
  end

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
    validateRepo(conn) |>  case do
      :ok -> IO.puts("/objects/batch post")
            {:ok, _, payload} = read_body(conn)
            IO.puts("------- Start batch ------")
            IO.inspect(payload)
            IO.puts("------- Response ------")

            case LfsApi.objects_batch(payload) do
              {:ok, response} -> %{status: 200, body: Poison.encode!(IO.inspect(response))}
              _ -> %{status: 500, body: Poison.encode!(%{:status => "Error"})}
            end
            |> build_response(conn)
      :error -> %{:status => "Authentication error"} |> Poison.encode!() |> build_err_auth_response(conn)
    end
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
    validateRepo(conn) |>  case do
      :ok -> url = conn.request_path
            read_multipart_put(conn, url, nil)
            %{status: 200, body: Poison.encode!(%{:status => "ok"})} |> build_response(conn)
      :error -> %{:status => "Authentication error"} |> Poison.encode!() |> build_err_auth_response(conn)
    end

  end

  post _ do
    IO.puts("@@@@@@@@@@@@@@ post")
    read_body(conn)
    health() |> build_response(conn)
    IO.puts("========= post")
  end

  get "/works" do
    {:ok, "it works"} |> build_response(conn)
  end

  get _ do
    health() |> build_response(conn)
  end

  defp validateRepo (conn) do
    auth=  Enum.find_value(conn.req_headers, fn x -> case x do {"authorization", auth} -> {"authorization", auth}; _ -> nil  end end)
    headers= [{"content-type", "application/json"}, auth]
    case AzdSecurityFilter.validateReadRepo("AW1371001_WSAdicionarFondos_TEST", headers) do
      :ok -> :ok
      :error -> :error
    end
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
  def build_err_auth_response(response, conn) do
    build_response(%{status: 401, body: response}, conn)
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


  def setup() do
    IO.puts("SETUP INSPECTOR")
    # register the tracer. just re-registers if called for multiple repos
    _ = OpenTelemetry.register_application_tracer(:lfs)

    :telemetry.attach(
      {__MODULE__, :plug_router_start},
      [:plug, :router_dispatch, :start],
      &__MODULE__.handle_start/4,
      nil
    )

    :telemetry.attach(
      {__MODULE__, :plug_router_stop},
      [:plug, :router_dispatch, :stop],
      &__MODULE__.handle_stop/4,
      nil
    )

    :telemetry.attach(
      {__MODULE__, :plug_router_exception},
      [:plug, :router_dispatch, :exception],
      &__MODULE__.handle_exception/4,
      nil
    )
  end

  @doc false
  def handle_start(_, _measurements, %{conn: conn, route: route}, _config) do
    save_parent_ctx()
    # setup OpenTelemetry context based on request headers
    :otel_propagator.text_map_extract(conn.req_headers)

    span_name = "#{route}"

    peer_data = Plug.Conn.get_peer_data(conn)

    user_agent = header_or_empty(conn, "User-Agent")
    host = header_or_empty(conn, "Host")
    peer_ip = Map.get(peer_data, :address)

    attributes =
      [
        "http.target": conn.request_path,
        "http.host": conn.host,
        "http.scheme": conn.scheme,
        "http.flavor": http_flavor(conn.adapter),
        "http.route": route,
        "http.user_agent": user_agent,
        "http.method": conn.method,
        "net.peer.ip": to_string(:inet_parse.ntoa(peer_ip)),
        "net.peer.port": peer_data.port,
        "net.peer.name": host,
        "net.transport": "IP.TCP",
        "net.host.ip": to_string(:inet_parse.ntoa(conn.remote_ip)),
        "net.host.port": conn.port
      ] ++ optional_attributes(conn)

    # TODO: Plug should provide a monotonic native time in measurements to use here
    # for the `start_time` option
    span_ctx = Tracer.start_span(span_name, %{attributes: attributes, kind: :server})

    Tracer.set_current_span(span_ctx)
  end

  @doc false
  def handle_stop(_, _measurements, %{conn: conn}, _config) do
    Tracer.set_attribute(:"http.status_code", conn.status)
    # For HTTP status codes in the 4xx and 5xx ranges, as well as any other
    # code the client failed to interpret, status MUST be set to Error.
    #
    # Don't set the span status description if the reason can be inferred from
    # http.status_code.
    if conn.status >= 400 do
      Tracer.set_status(OpenTelemetry.status(:error, ""))
    end

    Tracer.end_span()
    restore_parent_ctx()
  end

  @doc false
  def handle_exception(_, _measurements, metadata, _config) do
    %{kind: kind, stacktrace: stacktrace} = metadata
    # This metadata key changed from :error to :reason in Plug 1.10.3
    reason = metadata[:reason] || metadata[:error]

    exception = Exception.normalize(kind, reason, stacktrace)

    Span.record_exception(
      Tracer.current_span_ctx(),
      exception,
      stacktrace
    )

    Tracer.set_status(OpenTelemetry.status(:error, Exception.message(exception)))
    Tracer.set_attribute(:"http.status_code", 500)
    Tracer.end_span()
    restore_parent_ctx()
  end

  defp header_or_empty(conn, header) do
    case Plug.Conn.get_req_header(conn, header) do
      [] ->
        ""

      [host | _] ->
        host
    end
  end

  defp optional_attributes(conn) do
    ["http.client_ip": &client_ip/1, "http.server_name": &server_name/1]
    |> Enum.map(fn {attr, fun} -> {attr, fun.(conn)} end)
    |> Enum.reject(&is_nil(elem(&1, 1)))
  end

  defp client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [] ->
        nil

      [host | _] ->
        host
    end
  end

  defp server_name(_) do
    Application.get_env(:opentelemetry_plug, :server_name, nil)
  end

  defp http_flavor({_adapter_name, meta}) do
    case Map.get(meta, :version) do
      :"HTTP/1.0" -> :"1.0"
      :"HTTP/1.1" -> :"1.1"
      :"HTTP/2.0" -> :"2.0"
      :SPDY -> :SPDY
      :QUIC -> :QUIC
      nil -> ""
    end
  end

  @ctx_key {__MODULE__, :parent_ctx}
  defp save_parent_ctx() do
    ctx = Tracer.current_span_ctx()
    Process.put(@ctx_key, ctx)
  end

  defp restore_parent_ctx() do
    ctx = Process.get(@ctx_key, :undefined)
    Process.delete(@ctx_key)
    Tracer.set_current_span(ctx)
  end
end
