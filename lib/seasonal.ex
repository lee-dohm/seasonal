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

  @doc false
  def start(_type, _args) do
    Seasonal.Supervisor.start_link
  end
end
