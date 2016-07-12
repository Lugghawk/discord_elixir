defmodule DiscordElixir.Example do
  use DiscordElixir

  def handle_chat_message(message, discord) do
    IO.inspect("Got Message from channel #{message["channel_name"]}")
  end
end
