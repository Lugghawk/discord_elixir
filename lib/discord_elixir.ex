defmodule Discord do

  defmacro __using__(_) do
    quote do
      @behaviour :websocket_client_handler
      require Logger
      import Discord
      import DiscordElixir.Sending


      def start_link(token, wss_client \\ :websocket_client, rest_client \\ HTTPotion) do
        case DiscordElixir.Gateway.start(token) do
          {:ok, gateway_url} ->
            state = %{
              token: token,
              wss_client: wss_client,
              gateway: gateway_url,
              start_pid: self(),
              rest_api_url: "https://discordapp.com/api",
              rest_client: rest_client
            }
            bot_name_task = Task.async(fn -> DiscordElixir.Sending.bot_name(state) end)
            url = String.to_char_list(gateway_url)
            bot_name = Task.await(bot_name_task)
            state = Map.put(state, :bot_name, bot_name)
            wss_client.start_link(url, __MODULE__, state)
            receive do
              {:ok, discord} ->
                discord = Map.delete(discord, :start_pid)
                {:ok, discord}
              _ ->
                {:error}
            end
        end
      end

      def init(discord, socket) do
        discord = Map.put(discord, :socket, socket)
        identify(identification(discord), discord)
        {:ok, discord}
      end

      def identify(id, discord) do
        discord.wss_client.send({:text, Poison.encode!(id)}, discord.socket)
      end

      def identification(discord) do
        identification = %{
          token: discord.token,
          compress: "true",
          properties: %{
            "$os" => "elixir",
            "$browser" => "elixir_bot",
            "$device" => "elixir",
            "$referrer" => "",
            "$referring_domain" => ""
          }
        }

        %{
          op: 2,
          d: identification
        }
      end

      def websocket_info(message, _connection, state) do
        try do
          handle_info(message, state)
        rescue
          e -> handle_exception(e)
        end
      end

      def websocket_terminate(_message, _conn, state) do
        handle_disconnect(state)
      end

      def handle_message(%{"t" => "READY", "d" => %{"heartbeat_interval" => heartbeat_interval}}, _conn, state) do
        DiscordElixir.Heartbeat.start_heartbeat(state, heartbeat_interval)
        handle_connect(state)
        {:ok, state}
      end

      def handle_message(message = %{"t" => "GUILD_CREATE"}, _conn, state) do
        state = store_channels(message, state)
        send state.start_pid, {:ok, state}
        {:ok, state}
      end

      def store_channels(%{"d" => %{"channels" => channels}}, state) do
        channels =
          channels
          |> Enum.filter(fn chan -> chan["type"] == "text" end)
          |> Enum.map(fn chan -> %{id: chan["id"], name: chan["name"]} end)
        Map.put(state, :channels, channels)
      end

      def handle_message(message, _conn, state) do
        case message do
          %{"t" => "MESSAGE_CREATE", "d" => %{"content" => _content}} ->
            message
              |> add_channel_name(state)
              |> format_message
              |> handle_chat_message(state)
            {:ok, state}
          _ ->
            {:ok, state}
        end
      end
      def format_message(message) do
        %{
          author: message["d"]["author"]["username"],
          content: message["d"]["content"],
          channel_name: message["channel_name"],
         }
      end

      def websocket_handle({:text, message}, conn, state) do
        {:ok, new_state} = message |> convert_message |> handle_message(conn,state)
        {:ok, new_state}
      end

      def handle_exception(e) do
        IO.inspect "exception"
      end

      def convert_message(string_message) do
        message_map = Poison.Parser.parse!(string_message)
      end

      def add_channel_name(message, state) do
        Map.put(message, "channel_name",
         Enum.find(state.channels, fn channel -> Map.get(channel, :id) == message["d"]["channel_id"] end) |> Map.get(:name)
        )
      end

      def handle_chat_message(_message, _state), do: :ok

      def handle_disconnect(_state), do: :ok

      def handle_info(_message, _state), do: :ok

      def handle_connect(state), do: :ok

      defoverridable [ handle_chat_message: 2, handle_disconnect: 1, handle_info: 2, handle_connect: 1 ]
    end

  end


end
