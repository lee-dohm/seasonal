defmodule Seasonal do
  @moduledoc """
  A simple worker pool.

  Allows for the creation of worker pools with a fixed number of concurrent
  workers. Pools can be named or unnamed. Named pools can also be supervised. Jobs
  are queued as either anonymous functions or `{module, function, arguments}`
  tuples. Exceptions within a job end the job, but do not crash the pool.
  """
  use Application

  @doc """
  Creates a named, supervised pool with the specified number of concurrent workers.
  """
  def create_pool(name, workers) do
    Seasonal.PoolSupervisor.start_pool(name, workers)
  end

  @doc """
  Queues a job on the named pool.

  * `pool_name` - Name of the pool to execute the job on.
  * `func` - Function to execute. This can be either an anonymous function or a `{module, function, arguments}` tuple.

  Returns the key that uniquely identifies the job.
  """
  def queue(pool_name, func) do
    Seasonal.Pool.queue(pool_name, func)
  end

  @doc """
  Queues a job on the named pool after `time` in milliseconds has passed.

  Keep in mind that the job won't be inserted into the queue until after the specified amount of
  time has passed. So if the queue already contains more jobs than it can process right away, the
  scheduled job will have to wait even longer.

  * `pool_name` - Name of the pool to execute the job on.
  * `func` - Function to execute. This can be either an anonymous function or a `{module, function, arguments}` tuple.
  * `time` - Amount of time to wait in milliseconds.

  Returns `:ok`.
  """
  def queue_after(pool_name, func, time) do
    Seasonal.Scheduler.run_after(fn -> Seasonal.Pool.queue(pool_name, func) end, time)
  end

  @doc false
  def start(_type, _args) do
    Seasonal.Supervisor.start_link
  end
end
