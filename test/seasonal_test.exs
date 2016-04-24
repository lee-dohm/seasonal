defmodule Seasonal.Test do
  use ExUnit.Case

  setup_all do
    Seasonal.create_pool("test", 10)

    :ok
  end

  setup do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    {:ok, agent: agent}
  end

  test "create a named, supervised pool" do
    pool = Seasonal.Pool.whereis("test")

    assert is_pid(pool)
    assert Seasonal.Pool.whereis("test") == pool
  end

  test "queue a job", %{agent: agent} do
    Seasonal.queue("test", fn -> update(agent) end)

    assert get(agent) == 5
  end

  test "queue a job after some time", %{agent: agent} do
    Seasonal.queue_after("test", fn -> update(agent) end, 200)
    assert get(agent) == 0
    :timer.sleep(400)

    assert get(agent) == 5
  end

  test "killed pools are restarted automatically" do
    pool = Seasonal.Pool.whereis("test")

    Process.exit(pool, :kill)
    :timer.sleep(100)
    new_pid = Seasonal.Pool.whereis("test")

    assert is_pid(new_pid)
  end

  defp get(agent), do: Agent.get(agent, fn(value) -> value end)
  defp update(agent), do: Agent.update(agent, fn(value) -> value + 5 end)
end
