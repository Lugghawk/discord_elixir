defmodule DiscordElixir.Sending do

  def send_message(content, dest_channel, discord) do
   message = %{content: content} |> Poison.encode!
   channel_id = Enum.find(discord.channels, fn chan -> chan.name == dest_channel end) |> Map.get(:id)
   HTTPotion.post "#{discord.rest_api_url}/channels/#{channel_id}/messages", [body: message, headers: headers(discord)] 
  end

  def headers(discord) do
     ["Authorization": "Bot " <> discord.token, "Content-Type": "application/json"]
  end

  def bot_name(discord) do
    HTTPotion.get("#{discord.rest_api_url}/oauth2/applications/@me", headers: headers(discord)).body
      |> Poison.Parser.parse!
      |> Map.get("name")
  end


end

