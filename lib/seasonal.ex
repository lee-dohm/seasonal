defmodule Seasonal do
  @moduledoc """
  A simple worker pool.

  Allows for the creation of worker pools with a fixed number of concurrent
  workers. Pools can be named or unnamed. Named pools can also be supervised. Jobs
  are queued as either anonymous functions or `{module, function, arguments}`
  tuples. Exceptions within a job end the job, but do not crash the pool.
  """
  use Application

  @doc false
  def start(_type, _args) do
    Seasonal.Supervisor.start_link
  end
end
