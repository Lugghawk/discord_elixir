defmodule DiscordElixir do

  defmacro __using__(_) do
    quote do
      @behaviour :websocket_client_handler
      require Logger
      import DiscordElixir


      def start_link(token, client \\ :websocket_client) do
        case DiscordElixir.Gateway.start(token) do
          {:ok, gateway_url} ->
            state = %{
              token: token,
              client: client,
              gateway: gateway_url
            }
            url = String.to_char_list(gateway_url)
            client.start_link(url, __MODULE__, state)
            state.client
        end
      end

      def identify(discord) do
        identification = %{
          token: discord.token,
          compress: "true",
          properties: %{
            "$os" => "elixir",
            "$browser" => "pricecheck",
            "$device" => "pricecheck",
            "$referrer" => "",
            "$referring_domain" => ""
          }
        }

        identify_opcode = %{
          op: 2,
          d: identification
        }
        discord.client.send({:text, Poison.encode!(identify_opcode)}, discord.socket)
      end

      def init(%{gateway: gateway, client: client, token: token}, socket) do
        discord = %{
          socket: socket,
          client: client,
          token: token,
          gateway_url: gateway
        }
        on_connect(discord)
        {:ok, discord}
      end

      def on_connect(discord) do
        identify(discord)
      end

      def websocket_info(:start, _connection, state) do
        IO.inspect "info1"
        {:ok, state}
      end

      def websocket_info(message, _connection, gateway) do
        IO.inspect "info2"
        try do
          IO.inspect message
        rescue
          e -> handle_exception(e)
        end
      end

      def websocket_terminate(_, _, _) do
        IO.inspect("ended websocket")
      end

      def handle_message(%{"t" => "READY", "d" => %{"heartbeat_interval" => heartbeat_interval}}, conn, state) do
        IO.puts "handling READY"
        DiscordElixir.Heartbeat.start_heartbeat(state, heartbeat_interval)
        {:ok, state}
      end

      def handle_message(_message, _conn, _state) do
        IO.puts "handling other message"
      end

      def websocket_handle({:text, message}, conn, state) do
        IO.puts "got message"
        message |> convert_message |> handle_message(conn,state)
        {:ok, state}
      end

      def handle_exception(e) do
        IO.inspect "exception"
      end

      def convert_message(string_message) do
        Poison.Parser.parse!(string_message)
      end

    end

  end


end
