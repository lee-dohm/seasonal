defmodule Seasonal.Pool do
  @moduledoc """
  A simple concurrent jobs pool.

  You can spawn jobs synchronously:

      {:ok, pool} = Seasonal.Pool.start_link(10)
      Enum.each 1..99, fn(_) ->
        spawn fn ->
          Seasonal.Pool.run!(pool, fn -> :timer.sleep(100) end)
        end
      end
      Seasonal.Pool.run!(pool, fn -> :timer.sleep(100) end)
      Seasonal.Pool.join(pool)     # Should take ~1s

  `Seasonal.Pool.run!/4` blocks until the job is done and returns the job's
  result, or reraise if it had an error.

  You can also spawn jobs asynchronously:

      {:ok, pool} = Seasonal.Pool.start_link(10)
      Enum.each 1..100, fn(_) ->
        Seasonal.Pool.async(pool, fn -> :timer.sleep(100) end)
      end
      Seasonal.Pool.join(pool)     # Should take ~1s

  There is currently no way to retrieve an async job's result.

  `Seasonal.Pool.start_link/2` second argument is an array of options passed to
  `GenServer.start_link/3`. For example to create a named pool:

      Seasonal.Pool.start_link(10, name: :jobs_pool)
      Seasonal.Pool.run!(:jobs_pool, fn -> :timer.sleep(100) end)

  """

  use GenServer

  defmodule State do
    @moduledoc false

    defstruct [
      max_concurrent_jobs: 1,

      active_jobs: %{},
      queued_jobs: :queue.new(),
      queued_keys: HashSet.new(),
      waiters: %{},
      joiners: [],
    ]
  end

  # --------------------------------------------------------------------------
  # Public API

  @doc """
  Start a pool with `max_concurrent_jobs` execution slots.

  `genserver_options` is passed to `GenServer.start_link/3`.
  """
  def start_link(max_concurrent_jobs, genserver_options \\ []) do
    state = %State{max_concurrent_jobs: max_concurrent_jobs}
    GenServer.start_link(__MODULE__, state, genserver_options)
  end

  @doc """
  Queues a job in the pool.

  `fun` can either be an anonymous function with an arity of 0 or a
  `{mod, fun, args}` tuple.

  By default, the function is run asynchronously and no return value or other
  information is returned to the caller. If the option `sync: true` is given,
  the function is run synchronously and the return value and any exceptions or
  errors are returned to the caller. If the option `sync: true` is given, an
  optional `timeout` can be specified in milliseconds or `:infinity` to wait
  forever.

  The `key` option can be specified to make a job unique. A second occurrence
  of the same key cannot be executing or queued while the first is in the pool.
  """
  def queue(pool, fun, options \\ [])
  def queue(pool, fun, options) do
    timeout = Keyword.get(options, :timeout, :infinity)
    sync = Keyword.get(options, :sync, false)
    key = Keyword.get(options, :key, nil)

    queue_job(pool, fun, {sync, key, timeout})
  end

  @doc """
  Wait until all jobs are finished.
  """
  def join(pool, timeout \\ :infinity) do
    GenServer.call(pool, {:join}, timeout)
  end

  # --------------------------------------------------------------------------
  # GenServer implementation

  @doc false
  def handle_call({:run, fun, key}, from, state) do
    key = maybe_create_key(key)
    state = state
            |> run_job(fun, key)
            |> add_waiter(key, from)
    {:noreply, state}
  end

  @doc false
  def handle_call({:async, fun, key}, _from, state) do
    key = maybe_create_key(key)
    state = run_job(state, fun, key)
    {:reply, key, state}
  end

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
  def handle_info(message, state) do
    active_tasks = Map.values(state.active_jobs)

    case Task.find(active_tasks, message) do
      {{key, result}, _task} ->
        state = state
                |> remove_active_job(key)
                |> notify_waiters(key, result)
                |> run_next_job()
      nil -> :ok
    end

    {:noreply, state}
  end

  # --------------------------------------------------------------------------
  # Helpers

  defp notify_waiters(state, key, result) do
    if Map.has_key?(state.waiters, key) do
      Enum.each state.waiters[key], fn(waiter) ->
        GenServer.reply(waiter, result)
      end
      update_in(state.waiters, &Map.delete(&1, key))
    else
      state
    end
  end

  defp add_waiter(state, key, waiter) do
    waiters = Map.get(state.waiters, key, HashSet.new())
              |> HashSet.put(waiter)
    update_in(state.waiters, &Map.put(&1, key, waiters))
  end

  defp remove_active_job(state, key) do
    update_in(state.active_jobs, &Map.delete(&1, key))
  end

  defp unqueue_job(state, new_queued_jobs, key) do
    state = put_in(state.queued_jobs, new_queued_jobs)
    update_in(state.queued_keys, &Set.delete(&1, key))
  end

  defp add_joiner(state, joiner) do
    update_in(state.joiners, &([joiner | &1]))
  end

  defp run_next_job(state) do
    case :queue.out(state.queued_jobs) do
      {{:value, {key, fun}}, new_queued_jobs} ->
        state
        |> unqueue_job(new_queued_jobs, key)
        |> run_job(fun, key)
      {:empty, _} ->
        if Map.size(state.active_jobs) == 0 do
          state
          |> notify_joiners()
          |> clear_joiners()
        else
          state
        end
    end
  end

  defp notify_joiners(state) do
    Enum.each state.joiners, fn(joiner) ->
      GenServer.reply(joiner, :done)
    end
    state
  end

  defp clear_joiners(state) do
    put_in(state.joiners, [])
  end

  defp maybe_create_key(nil), do: UUID.uuid4()
  defp maybe_create_key(key), do: key

  defp run_job(state, fun, key) do
    # Check a job with `key` is not already active or queued
    if not Map.has_key?(state.active_jobs, key) and not Set.member?(state.queued_keys, key) do
      if Map.size(state.active_jobs) < state.max_concurrent_jobs do
        # There are slots available, execute job now

        # Wrap fun to catch exceptions, since we want to reraise them in the client
        # processes, not in this GenServer
        wrapped_fun = fn ->
          try do
            {key, {:ok, run_fun_or_mfa(fun)}}
          catch
            class, reason ->
              stacktrace = System.stacktrace()
              {key, {class, reason, stacktrace}}
          end
        end

        # Create Task and put in in active jobs
        task = Task.async(wrapped_fun)
        state = update_in(state.active_jobs, &Map.put(&1, key, task))
      else
        # No slots available, queue job
        state = update_in(state.queued_jobs, &:queue.in({key, fun}, &1))
        state = update_in(state.queued_keys, &Set.put(&1, key))
      end
    end
    state
  end

  defp run_fun_or_mfa({mod, fun, args}), do: apply(mod, fun, args)
  defp run_fun_or_mfa(fun), do: fun.()

  defp maybe_reraise({:ok, result}), do: result
  defp maybe_reraise({class, reason, stacktrace}) do
    :erlang.raise(class, reason, stacktrace)
  end

  defp queue_job(pool, fun, {true, key, timeout}) do
    GenServer.call(pool, {:run, fun, key}, timeout)
    |> maybe_reraise()
  end

  defp queue_job(pool, fun, {false, key, _}) do
    GenServer.call(pool, {:async, fun, key})
  end
end
