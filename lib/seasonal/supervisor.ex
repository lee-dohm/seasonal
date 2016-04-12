defmodule Seasonal.Supervisor do
  @moduledoc """
  Supervisor for Seasonal worker pools.
  """

  use Supervisor

  @doc """
  Starts the supervisor.
  """
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :seasonal_supervisor)
  end

  @doc """
  Starts a worker pool under supervision.
  """
  def start_pool(name, workers) do
    Supervisor.start_child(:seasonal_supervisor, [name, workers])
  end

  @doc false
  def init(_) do
    children = [
      worker(Seasonal.Pool, [], restart: :transient)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
