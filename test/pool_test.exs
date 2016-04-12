defmodule Seasonal.Pool.Test do
  use ExUnit.Case, async: true

  alias Seasonal.Pool

  setup do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, pool} = Pool.start_link(10)

    {:ok, agent: agent, pool: pool}
  end

  test "creating a pool of workers", %{pool: pool} do
    assert is_pid(pool)
    assert Pool.workers(pool) == 10
  end

  test "queue a job", %{agent: agent, pool: pool} do
    Pool.queue(pool, fn -> update(agent) end)

    assert get(agent) == 5
  end

  test "queue multiple jobs", %{agent: agent, pool: pool} do
    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)

    Pool.join(pool)

    assert get(agent) == 15
  end

  test "queue more jobs than the pool can run at once", %{agent: agent} do
    {:ok, pool} = Pool.start_link(1)

    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)
    Pool.queue(pool, fn -> update(agent) end)

    Pool.join(pool)

    assert get(agent) == 15
  end

  test "an error in a job doesn't take down the pool", %{pool: pool} do
    Pool.queue(pool, fn -> raise ArithmeticError, message: "test" end)

    assert Process.alive?(pool)
  end

  test "create a named pool" do
    {:ok, pool} = Pool.start_link("test", 10)

    assert is_pid(pool)
    assert Pool.workers("test") == 10
  end

  defp get(agent), do: Agent.get(agent, fn(value) -> value end)
  defp update(agent), do: Agent.update(agent, fn(value) -> value + 5 end)
end
