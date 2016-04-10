defmodule Seasonal.Pool do
  use GenServer

  defmodule State do
    @moduledoc false

    defstruct [
      workers: 1,

      active_jobs: %{},
      queued_jobs: :queue.new(),
      queued_keys: HashSet.new(),
      waiters: %{},
      joiners: [],
    ]
  end

  ### Client API

  @doc """
  Start a pool with the given number of workers.
  """
  def start_link(workers, genserver_options \\ []) do
    state = %State{workers: workers}
    GenServer.start_link(__MODULE__, state, genserver_options)
  end

  @doc """
  Wait until all jobs are finished.
  """
  def join(pool, timeout \\ :infinity) do
    GenServer.call(pool, {:join}, timeout)
  end

  @doc """
  Queue a job.
  """
  def queue(pool, func) do
    GenServer.call(pool, {:queue, func, nil})
  end

  @doc """
  Get the number of workers for the given pool.
  """
  def workers(pool) do
    GenServer.call(pool, :workers)
  end

  ### Server API

  @doc false
  def handle_call({:join}, from, state) do
    if Map.size(state.active_jobs) > 0 or :queue.len(state.queued_jobs) > 0 do
      state = add_joiner(state, from)
      {:noreply, state}
    else
      {:reply, :done, state}
    end
  end

  @doc false
  def handle_call({:queue, func, key}, _from, state) do
    key = maybe_create_key(key)
    state = run_job(state, func, key)
    {:reply, key, state}
  end

  @doc false
  def handle_call(:workers, _from, state = %State{workers: workers}) do
    {:reply, workers, state}
  end

  @doc false
  def handle_info(message, state) do
    active_tasks = Map.values(state.active_jobs)

    case Task.find(active_tasks, message) do
      {{key, _result}, _task} ->
        state = state
                |> remove_finished_job(key)
                |> run_next_job

      nil -> :ok
    end

    {:noreply, state}
  end

  ### Helpers

  defp add_joiner(state, joiner), do: update_in(state.joiners, &([joiner | &1]))

  defp clear_joiners(state) do
    put_in(state.joiners, [])
  end

  defp maybe_create_key(nil), do: UUID.uuid4()

  defp notify_joiners(state) do
    Enum.each(state.joiners, fn(joiner) -> GenServer.reply(joiner, :done) end)

    state
  end

  defp remove_finished_job(state, key), do: update_in(state.active_jobs, &Map.delete(&1, key))

  defp run_fun_or_mfa({mod, func, args}), do: apply(mod, func, args)
  defp run_fun_or_mfa(func), do: func.()

  defp run_job(state, func, key) do
    if Map.size(state.active_jobs) < state.workers do
      wrapped_func = fn ->
        try do
          {key, {:ok, run_fun_or_mfa(func)}}
        catch
          class, reason ->
            stacktrace = System.stacktrace()
            {key, {class, reason, stacktrace}}
        end
      end

      task = Task.async(wrapped_func)
      state = update_in(state.active_jobs, &Map.put(&1, key, task))
    else
      state = update_in(state.queued_jobs, &:queue.in({key, func}, &1))
      state = update_in(state.queued_keys, &Set.put(&1, key))
    end

    state
  end

  defp run_next_job(state) do
    case :queue.out(state.queued_jobs) do
      {{:value, {key, func}}, new_queued_jobs} ->
        state
        |> unqueue_job(new_queued_jobs, key)
        |> run_job(func, key)

      {:empty, _} ->
        if Map.size(state.active_jobs) == 0 do
          state
          |> notify_joiners
          |> clear_joiners
        else
          state
        end
    end
  end

  defp unqueue_job(state, new_queued_jobs, key) do
    state = put_in(state.queued_jobs, new_queued_jobs)
    update_in(state.queued_keys, &Set.delete(&1, key))
  end
end
