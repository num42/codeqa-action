defmodule MyApp.Cache do
  @moduledoc ""

  @doc ""
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    ttl = Keyword.get(opts, :ttl, :timer.minutes(5))
    :ets.new(name, [:set, :public, :named_table, read_concurrency: true])
    Agent.start_link(fn -> %{name: name, ttl: ttl} end, name: :"#{name}_agent")
  end

  @doc ""
  @spec get(atom(), term()) :: term() | nil
  def get(cache, key) do
    case :ets.lookup(cache, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at, do: value, else: nil

      [] ->
        nil
    end
  end

  @doc ""
  @spec put(atom(), term(), term(), keyword()) :: true
  def put(cache, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, default_ttl(cache))
    expires_at = System.monotonic_time(:millisecond) + ttl
    :ets.insert(cache, {key, value, expires_at})
  end

  @doc ""
  @spec delete(atom(), term()) :: true
  def delete(cache, key) do
    :ets.delete(cache, key)
  end

  @doc ""
  @spec flush(atom()) :: true
  def flush(cache) do
    :ets.delete_all_objects(cache)
  end

  @doc ""
  @spec fetch(atom(), term(), (-> term())) :: term()
  def fetch(cache, key, fun) do
    case get(cache, key) do
      nil ->
        value = fun.()
        put(cache, key, value)
        value

      value ->
        value
    end
  end

  @doc ""
  @spec size(atom()) :: non_neg_integer()
  def size(cache) do
    :ets.info(cache, :size)
  end

  @doc ""
  @spec stats(atom()) :: map()
  def stats(cache) do
    %{
      size: size(cache),
      memory: :ets.info(cache, :memory)
    }
  end

  defp default_ttl(cache) do
    agent = :"#{cache}_agent"
    Agent.get(agent, & &1.ttl)
  end
end
