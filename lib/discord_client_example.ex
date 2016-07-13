defmodule DiscordElixir.Example do
  use DiscordElixir

  def handle_chat_message(message, discord) do
    unless (message.author == discord.bot_name) do
      #send_message("Got message in #{message.channel_name}!", "bot_test", discord)
    end

  end


end
