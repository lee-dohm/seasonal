defmodule Seasonal.PoolRegistry do
  @moduledoc """
  Keeps a registry of named worker pools.
  """
  use GenServer

  ### Client API

  @doc """
  Starts the registry.

  * `name`: Name of the registry

  Returns `{:ok, pid}` if successful, `{:error, reason}` otherwise.
  """
  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @doc """
  Creates a pool in the registry.

  If a pool by the given name already exists, it is used instead of creating
  a new one.

  * `registry`: Name of the registry
  * `name`: Name to give to the pool
  * `size`: Size of the pool in maximum concurrent workers

  Returns `{:ok, pid}` if the pool was created or pre-existing, otherwise
  `:error`.
  """
  def create(registry, name, size) do
    GenServer.call(registry, {:create, name, size})
  end

  @doc """
  Looks up a pool in the registry.

  * `name`: Name of the pool to find

  Returns `{:ok, pid}` if the pool was found, otherwise `:error`.
  """
  def lookup(registry, name) do
    GenServer.call(registry, {:lookup, name})
  end

  @doc """
  Stops the registry.
  """
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
      {:ok, pool} = Seasonal.Pool.start_link(size)
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
