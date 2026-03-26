defmodule MyApp.Cache do
  @moduledoc """
  ETS-backed in-memory cache with per-entry TTL support.

  Each cache instance is an ETS table created at startup via `start_link/1`.
  Values are stored with an expiry timestamp and are considered stale after
  their TTL has elapsed. Stale entries are not automatically evicted but are
  ignored on read.

  Use `fetch/3` for the common read-through pattern to avoid redundant
  computations or database calls.
  """

  @doc """
  Creates a new cache ETS table and starts its companion Agent.

  Accepts the following options:
  - `:name` — the atom name for the ETS table (defaults to `#{__MODULE__}`)
  - `:ttl` — default time-to-live in milliseconds (defaults to 5 minutes)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    ttl = Keyword.get(opts, :ttl, :timer.minutes(5))
    :ets.new(name, [:set, :public, :named_table, read_concurrency: true])
    Agent.start_link(fn -> %{name: name, ttl: ttl} end, name: :"#{name}_agent")
  end

  @doc """
  Returns the cached value for `key`, or `nil` if missing or expired.
  """
  @spec get(atom(), term()) :: term() | nil
  def get(cache, key) do
    case :ets.lookup(cache, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at, do: value, else: nil

      [] ->
        nil
    end
  end

  @doc """
  Stores `value` under `key` in the cache with an optional `:ttl` override.

  If `:ttl` is not provided, the cache's default TTL is used.
  """
  @spec put(atom(), term(), term(), keyword()) :: true
  def put(cache, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, default_ttl(cache))
    expires_at = System.monotonic_time(:millisecond) + ttl
    :ets.insert(cache, {key, value, expires_at})
  end

  @doc """
  Removes the entry for `key` from the cache.
  """
  @spec delete(atom(), term()) :: true
  def delete(cache, key), do: :ets.delete(cache, key)

  @doc """
  Removes all entries from the cache without deleting the table itself.
  """
  @spec flush(atom()) :: true
  def flush(cache), do: :ets.delete_all_objects(cache)

  @doc """
  Returns the cached value for `key`, computing and storing it via `fun` on a miss.

  This is the preferred read-through pattern to avoid duplicate work:

      MyApp.Cache.fetch(:my_cache, {:user, id}, fn -> Accounts.get_user!(id) end)
  """
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

  @doc """
  Returns the number of entries currently stored in the cache table.
  """
  @spec size(atom()) :: non_neg_integer()
  def size(cache), do: :ets.info(cache, :size)

  defp default_ttl(cache) do
    Agent.get(:"#{cache}_agent", & &1.ttl)
  end
end
