defmodule DiscordElixir.Heartbeat do

  def start_heartbeat(discord, time_between_heartbeat) do
    spawn_link(fn ->
      do_heartbeat(discord, time_between_heartbeat)
    end)
  end

  def do_heartbeat(discord = %{wss_client: client, socket: socket}, sleep_time) do

    :timer.sleep sleep_time
    client.send({:text, heartbeat}, socket);
    do_heartbeat(discord, sleep_time)
  end

  def heartbeat do
    %{
      op: 1,
      d: 0
    } |> Poison.encode!
  end

  

end
