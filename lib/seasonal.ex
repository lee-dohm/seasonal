defmodule Seasonal do
  @moduledoc """
  A simple worker pool.

  Allows for the creation of named or unnamed worker pools with a fixed number
  of concurrent workers. Jobs are queued as either anonymous functions or
  `{module, function, arguments}` tuples. Exceptions within a job end the job,
  but do not crash the pool.
  """
  use Application
end
