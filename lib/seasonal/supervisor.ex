defmodule Seasonal.Supervisor do
  use Supervisor

  @doc """
  Starts the supervisor.
  """
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: :seasonal_supervisor)
  end

  @doc false
  def init(_) do
    children = [
      supervisor(Seasonal.PoolSupervisor, []),
      worker(Seasonal.Scheduler, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
