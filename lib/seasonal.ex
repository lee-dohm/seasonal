defmodule Seasonal do
  use Application

  @doc false
  def start(_type, _args) do
    Seasonal.Supervisor.start_link
  end
end
