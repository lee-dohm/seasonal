defmodule Seasonal.Scheduler do
  use GenServer

  require Logger

  ### Client API ###

  def start_link(name \\ :pain_view_scheduler) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def run_after(name \\ :pain_view_scheduler, func, time) do
    GenServer.cast(name, {:run_after, func, time})
  end

  ### Server API ###

  @doc false
  def init, do: {:ok, nil}

  @doc false
  def handle_cast({:run_after, func, time}, state) do
    Process.send_after(self, {:run, func}, time)

    {:noreply, state}
  end

  @doc false
  def handle_info({:run, func}, state) do
    try do
      run(func)
    catch
      class, reason -> Logger.error("#{class} error: #{reason}")
    end

    {:noreply, state}
  end

  defp run({mod, func, args}), do: apply(mod, func, args)
  defp run(func), do: func.()
end
