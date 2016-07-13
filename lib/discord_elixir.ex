defmodule DiscordElixir do

  defmacro __using__(_) do
    quote do
      @behaviour :websocket_client_handler
      require Logger
      import DiscordElixir
      import DiscordElixir.Sending


      def start_link(token, client \\ :websocket_client) do
        case DiscordElixir.Gateway.start(token) do
          {:ok, gateway_url} ->
            state = %{
              token: token,
              client: client,
              gateway: gateway_url,
              start_pid: self(),
              rest_api_url: "https://discordapp.com/api",
            }
            bot_name_task = Task.async(fn -> DiscordElixir.Sending.bot_name(state) end)
            url = String.to_char_list(gateway_url)
            bot_name = Task.await(bot_name_task)
            state = Map.put(state, :bot_name, bot_name)
            client.start_link(url, __MODULE__, state)
            receive do
              {:ok, discord} ->
                discord = Map.delete(discord, :start_pid)
                {:ok, discord}
              message ->
                {:error}
            end
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

      def init(discord, socket) do
        discord = Map.put(discord, :socket, socket)
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
        DiscordElixir.Heartbeat.start_heartbeat(state, heartbeat_interval)
        {:ok, state}
      end

      def handle_message(message = %{"t" => "GUILD_CREATE"}, conn, state) do
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

      defoverridable [ handle_chat_message: 2 ]
    end

  end


end
