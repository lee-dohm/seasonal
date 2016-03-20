defmodule Seasonal.Pool.Test do
  use ExUnit.Case, async: true

  alias Seasonal.Pool

  test "creating a pool" do
    assert {:ok, pool} = Pool.start_link(10)
    assert is_pid(pool)
  end

  test "simple sync job" do
    {:ok, jobs} = Pool.start_link(10)
    ret = Pool.run!(jobs, fn -> 1 end, 1000)
    assert ret == 1
  end

  test "parallel sync jobs" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, jobs} = Pool.start_link(10)
    increment = fn -> Agent.update(agent, &(&1 + 1)) end
    Enum.each 1..99, fn(_) ->
      spawn_link fn ->
        Pool.run!(jobs, increment)
      end
    end
    Pool.run!(jobs, increment)
    Pool.join(jobs)
    assert Agent.get(agent, fn value -> value end) == 100
  end

  test "parallel async jobs" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, jobs} = Pool.start_link(10)
    increment = fn -> Agent.update(agent, &(&1 + 1)) end
    Enum.each 1..100, fn(_) ->
      Pool.async(jobs, increment)
    end
    Pool.join(jobs)
    assert Agent.get(agent, fn value -> value end) == 100
  end

  test "tasks crashes bubble up to caller" do
    {:ok, jobs} = Pool.start_link(10)
    assert_raise RuntimeError, fn ->
      Pool.run!(jobs, fn -> raise "foo" end, 1000)
    end
  end

  test "tasks crashes don't break the pool" do
    {:ok, jobs} = Pool.start_link(10)
    assert_raise RuntimeError, fn ->
      Pool.run!(jobs, fn -> raise "foo" end, 1000)
    end
    ret = Pool.run!(jobs, fn -> 1 end, 1000)
    assert ret == 1
  end

  test "jobs with explicit keys don't mix up" do
    {:ok, jobs} = Pool.start_link(3)
    Enum.each 1..10, fn(_) ->
      spawn_link fn ->
        uid = UUID.uuid4()
        returned_uid = Pool.run!(jobs, fn -> uid end, uid)
        assert returned_uid == uid
      end
    end
    :timer.sleep(100)
    Pool.join(jobs)
  end

  test "tasks exits bubble up to caller" do
    {:ok, jobs} = Pool.start_link(10)
    assert catch_exit(Pool.run!(jobs, fn -> exit 1 end)) == 1
  end

  test "tasks exits don't break the pool" do
    {:ok, jobs} = Pool.start_link(10)
    assert catch_exit(Pool.run!(jobs, fn -> exit 1 end)) == 1
    assert Pool.run!(jobs, fn -> 1 end) == 1
  end

  test "tasks throws bubble up to caller" do
    {:ok, jobs} = Pool.start_link(10)
    assert catch_throw(Pool.run!(jobs, fn -> throw 1 end)) == 1
  end

  test "tasks throws don't break the pool" do
    {:ok, jobs} = Pool.start_link(10)
    assert catch_throw(Pool.run!(jobs, fn -> throw 1 end)) == 1
    assert Pool.run!(jobs, fn -> 1 end) == 1
  end

  test "exit stack is preserved" do
    {:ok, jobs} = Pool.start_link(10)
    try do
      Pool.run!(jobs, fn -> exit 1 end)
    catch
      :exit, 1 ->
        stack = System.stacktrace()
        frame = Enum.at(stack, 0)
        assert {Pool.Test, _, 0, [file: 'test/pool_test.exs', line: _]} = frame
        frame = Enum.at(stack, 1)
        assert {Pool, _, 2, [file: 'lib/seasonal/pool.ex', line: _]} = frame
      class, term ->
        raise "expected {:exit, 1}, got {#{inspect class}, #{inspect term}}"
    end
  end

  test "throw stack is preserved" do
    {:ok, jobs} = Pool.start_link(10)
    try do
      Pool.run!(jobs, fn -> throw 1 end)
    catch
      :throw, 1 ->
        stack = System.stacktrace()
        frame = Enum.at(stack, 0)
        assert {Pool.Test, _, 0, [file: 'test/pool_test.exs', line: _]} = frame
        frame = Enum.at(stack, 1)
        assert {Pool, _, 2, [file: 'lib/seasonal/pool.ex', line: _]} = frame
      class, term ->
        raise "expected {:throw, 1}, got {#{inspect class}, #{inspect term}}"
    end
  end

  test "mfa run! form" do
    {:ok, jobs} = Pool.start_link(10)
    assert Pool.run!(jobs, {Pool.Test, :identity, [1]}) == 1
  end

  test "mfa async form" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    {:ok, jobs} = Pool.start_link(10)
    Pool.async(jobs, {Pool.Test, :increment, [agent]})
    Pool.join(jobs)
    assert Agent.get(agent, fn value -> value end) == 1
  end

  def identity(arg), do: arg
  def increment(agent), do: Agent.update(agent, &(&1 + 1))
end
