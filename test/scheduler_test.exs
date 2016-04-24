defmodule Seasonal.Scheduler.Test do
  use ExUnit.Case, async: true

  alias Seasonal.Scheduler

  setup do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, scheduler} = Scheduler.start_link(:test)

    {:ok, agent: agent, scheduler: scheduler}
  end

  test "creating the scheduler" do
    assert is_pid(GenServer.whereis(:test))
  end

  test "scheduling a function to run", %{agent: agent} do
    Scheduler.run_after(:test, fn -> update(agent) end, 100)
    :timer.sleep(200)

    assert get(agent) == 5
  end

  defp get(agent), do: Agent.get(agent, fn(value) -> value end)
  defp update(agent), do: Agent.update(agent, fn(value) -> value + 5 end)
end
