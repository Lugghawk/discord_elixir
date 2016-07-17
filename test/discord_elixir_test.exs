defmodule DiscordElixirTest do
  use ExUnit.Case
  doctest Discord

  defmodule Bot do
    use Discord
  end

  defmodule FakeWebSocketClient do
    def send(data, socket), do: {data, socket}
  end

  test "identification populated properly" do
    discord_state = %{
      token: "token",
    }
    identity = Bot.identification(discord_state)

    assert identity.op == 2

    identity_data = identity.d

    assert identity_data.token == "token"
    assert identity_data.compress == "true"

    identity_props = identity_data.properties

    assert identity_props["$os"] == "elixir"
    assert identity_props["$browser"] == "elixir_bot"
    assert identity_props["$device"] == "elixir"
  end

  test "identify sends identification" do
    discord_state = %{
      token: "token",
      wss_client: FakeWebSocketClient,
      socket: "socket"
    }

    identification = Bot.identification(discord_state)

    {{:text, data}, socket} = Bot.identify(identification, discord_state)

    assert socket == "socket"
    assert data == Poison.encode!(identification)
  end

  test "GUILD_CREATE message should store channels in state" do
    channels = [
      %{
        "type" => "text",
        "id" => "1",
        "name" => "chan1"
      },%{
        "type" => "text",
        "id" => "2",
        "name" => "chan2"
      },%{
        "type" => "text",
        "id" => "3",
        "name" => "chan3"
      }]

    message = %{
      "t" => "GUILD_CREATE",
      "d" => %{
        "channels" => channels
      }
    }


    Bot.handle_message(message, nil, %{start_pid: self})
    receive do
      {:ok, state} ->
        chanlist = state.channels
        assert Enum.count(chanlist) == 3
        assert Enum.at(chanlist, 0).name == "chan1"
        assert Enum.at(chanlist, 0).id == "1"
        assert Enum.at(chanlist, 1).name == "chan2"
        assert Enum.at(chanlist, 1).id == "2"
        assert Enum.at(chanlist, 2).name == "chan3"
        assert Enum.at(chanlist, 2).id == "3"
        _ ->
        flunk ("didn't return {:ok, state}")
    end
  end

  test "should format incoming messages correctly" do
    message = %{
      "t" => "MESSAGE_CREATE",
      "d" => %{
        "author" => %{
          "username" => "test_bot",
        },
        "content" => "message_text",
      },
      "channel_name" => "channel_name"
    }

    formatted = Bot.format_message(message)

    assert formatted.author == "test_bot"
    assert formatted.content == "message_text"
    assert formatted.channel_name == "channel_name"

  end

  test "adds channel name to message map" do
    channels = [
      %{
        id: "1",
        name: "channel 1"
      },%{
        id: "2",
        name: "channel 2"
      }
    ]

    state = %{
      channels: channels
    }

    message_one = %{
      "d" => %{
        "channel_id" => "1"
      }
    }

    message_one_state = Bot.add_channel_name(message_one, state)

    assert message_one_state["channel_name"] == "channel 1"

    message_two = %{
      "d" => %{
        "channel_id" => "2"
      }
    }

    message_two_state = Bot.add_channel_name(message_two, state)

    assert message_two_state["channel_name"] == "channel 2"
  end

end
