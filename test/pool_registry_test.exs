defmodule Seasonal.PoolRegistry.Test do
  use ExUnit.Case, async: true

  alias Seasonal.PoolRegistry

  setup context do
    {:ok, registry} = PoolRegistry.start_link(context.test)
    {:ok, registry: registry}
  end

  test "start a name registry", %{registry: registry} do
    assert is_pid(registry)
  end

  test "stop a name registry", %{registry: registry} do
    assert :ok = PoolRegistry.stop(registry)
  end

  test "spawns new pools", %{registry: registry} do
    assert PoolRegistry.lookup(registry, "foo") == :error

    PoolRegistry.create(registry, "foo", 10)
    assert {:ok, pool} = PoolRegistry.lookup(registry, "foo")
    assert is_pid(pool)
  end

  test "removes pools on exit", %{registry: registry} do
    PoolRegistry.create(registry, "foo", 10)
    {:ok, pool} = PoolRegistry.lookup(registry, "foo")
    GenServer.stop(pool)

    assert PoolRegistry.lookup(registry, "foo") == :error
  end
end
