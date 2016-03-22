defmodule Seasonal.Test do
  use ExUnit.Case, async: true

  test "create a pool" do
    {:ok, pool} = Seasonal.create("foo", 10)

    assert is_pid(pool)
  end

  test "queueing jobs on a pool" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    Seasonal.create("foo", 10)
    increment = fn -> Agent.update(agent, &(&1 + 1)) end

    Enum.each 1..100, fn(_) ->
      Seasonal.queue("foo", increment)
    end

    Seasonal.join("foo")

    assert Agent.get(agent, fn value -> value end) == 100
  end
end
