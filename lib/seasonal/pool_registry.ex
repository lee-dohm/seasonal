defmodule Seasonal.PoolRegistry do
  use GenServer

  ### Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def create(registry, name, size) do
    GenServer.call(registry, {:create, name, size})
  end

  def lookup(registry, name) do
    GenServer.call(registry, {:lookup, name})
  end

  def stop(registry) do
    GenServer.stop(registry)
  end

  ### Server Callbacks

  def init(:ok) do
    names = %{}
    refs = %{}

    {:ok, {names, refs}}
  end

  def handle_call({:create, name, size}, _from, {names, refs}) do
    if Map.has_key?(names, name) do
      {:reply, Map.fetch(names, name), {names, refs}}
    else
      {:ok, pool} = Seasonal.start_link(size)
      ref = Process.monitor(pool)
      refs = Map.put(refs, ref, name)
      names = Map.put(names, name, pool)

      {:reply, Map.fetch(names, name), {names, refs}}
    end
  end

  def handle_call({:lookup, name}, _from, {names, _} = state) do
    {:reply, Map.fetch(names, name), state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    {name, refs} = Map.pop(refs, ref)
    names = Map.delete(names, name)
    {:noreply, {names, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
