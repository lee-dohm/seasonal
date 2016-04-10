defmodule Seasonal.Pool.Test do
  use ExUnit.Case, async: true

  alias Seasonal.Pool

  test "creating a pool of workers" do
    assert {:ok, pool} = Pool.start_link(10)
    assert is_pid(pool)
    assert Pool.workers(pool) == 10
  end

  test "queue a job" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, pool} = Pool.start_link(10)

    Pool.queue(pool, fn -> update(agent) end)

    assert get(agent) == 5
  end

  test "queue multiple jobs" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, pool} = Pool.start_link(10)

    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)

    Pool.join(pool)

    assert get(agent) == 15
  end

  test "queue more jobs than the pool can run at once" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, pool} = Pool.start_link(1)

    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)

    Pool.join(pool)

    assert get(agent) == 15
  end

  defp get(agent), do: Agent.get(agent, fn(value) -> value end)
  defp update(agent), do: Agent.update(agent, fn(value) -> value + 5 end)
end
