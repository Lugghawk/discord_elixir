defmodule DiscordElixir.Gateway do
  @url "https://discordapp.com/api/gateway"

  def start(token) do
    {:ok, wss_url}
  end

  def wss_url do
    HTTPotion.get(@url).body |> Poison.Parser.parse! |> Map.get("url")
  end
end
