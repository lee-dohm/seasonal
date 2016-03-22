defmodule Seasonal do
  @moduledoc """
  A simple worker pool library.

  Allows for the creation of named or unnamed worker pools with a fixed number
  of concurrent workers. Jobs are queued as either anonymous functions or
  `{module, function, arguments}` tuples. Jobs can be either synchronous or
  asynchronous. Exceptions within a job end the job, but do not crash the pool.
  Additionally, exceptions are backpropagated to the process that scheduled the
  job.
  """
  use Application

  alias Seasonal.Pool
  alias Seasonal.PoolRegistry

  @doc false
  def start(_type, _args) do
    Seasonal.Supervisor.start_link
  end

  def create(name, max_jobs) do
    PoolRegistry.create(PoolRegistry, name, max_jobs)
  end

  def join(name) do
    {:ok, pool} = PoolRegistry.lookup(PoolRegistry, name)
    Pool.join(pool)
  end

  def lookup(name), do: PoolRegistry.lookup(PoolRegistry, name)

  def queue(name, fun) do
    {:ok, pool} = PoolRegistry.lookup(PoolRegistry, name)
    Pool.queue(pool, fun)
  end
end
