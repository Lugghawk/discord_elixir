defmodule DiscordElixir.Sending do
  @api_url "https://discordapp.com/api"

  def send_message(content, dest_channel, discord) do
   message = %{content: content} |> Poison.encode!
   channel_id = Enum.find(discord.channels, fn chan -> chan.name == dest_channel end) |> Map.get(:id)
   HTTPotion.post "https://discordapp.com/api/channels/#{channel_id}/messages", [body: message, headers: ["Authorization": "Bot " <> discord.token, "Content-Type": "application/json"]] 
  end
end

