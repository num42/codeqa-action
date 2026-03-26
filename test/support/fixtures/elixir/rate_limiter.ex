defmodule Test.Fixtures.Elixir.RateLimiter do
  @moduledoc false
  use Test.LanguageFixture, language: "elixir rate_limiter"

  @code ~S'''
  defmodule RateLimiter.Behaviour do
    @moduledoc "Contract for rate limiter backends."
    @callback allow?(key :: term(), cost :: pos_integer()) :: boolean()
    @callback reset(key :: term()) :: :ok
    @callback stats(key :: term()) :: {:ok, map()} | {:error, :not_found}
  end

  defmodule RateLimiter.Bucket do
    @moduledoc "Token bucket state for a single rate-limited key."
    @enforce_keys [:capacity, :tokens, :refill_rate]
    defstruct [:capacity, :tokens, :refill_rate, last_refill: nil]

    @doc "Creates a new bucket with full capacity."
    @spec new(pos_integer(), pos_integer()) :: t()
    def new(capacity, refill_rate) when capacity > 0 and refill_rate > 0 do
      %__MODULE__{capacity: capacity, tokens: capacity, refill_rate: refill_rate, last_refill: System.monotonic_time(:millisecond)}
    end

    @doc "Consumes tokens from the bucket. Returns updated bucket or error."
    @spec consume(t(), pos_integer()) :: {:ok, t()} | {:error, :rate_limited}
    def consume(%__MODULE__{tokens: tokens} = bucket, cost) when tokens >= cost do
      {:ok, %{bucket | tokens: tokens - cost}}
    end
    def consume(%__MODULE__{}, _cost), do: {:error, :rate_limited}

    @doc "Refills the bucket based on elapsed time."
    @spec refill(t()) :: t()
    def refill(%__MODULE__{tokens: t, capacity: cap, refill_rate: rate, last_refill: last} = bucket) do
      now = System.monotonic_time(:millisecond)
      elapsed_ms = now - last
      new_tokens = min(cap, t + div(elapsed_ms * rate, 1000))
      %{bucket | tokens: new_tokens, last_refill: now}
    end
  end

  defmodule RateLimiter.Server do
    @moduledoc "GenServer-backed rate limiter with configurable buckets."
    @behaviour RateLimiter.Behaviour
    use GenServer

    @doc "Starts the rate limiter server."
    @spec start_link(keyword()) :: GenServer.on_start()
    def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

    @impl RateLimiter.Behaviour
    @spec allow?(term(), pos_integer()) :: boolean()
    def allow?(key, cost \\ 1), do: GenServer.call(__MODULE__, {:allow, key, cost})

    @impl RateLimiter.Behaviour
    @spec reset(term()) :: :ok
    def reset(key), do: GenServer.cast(__MODULE__, {:reset, key})

    @impl RateLimiter.Behaviour
    @spec stats(term()) :: {:ok, map()} | {:error, :not_found}
    def stats(key), do: GenServer.call(__MODULE__, {:stats, key})

    @impl GenServer
    def init(opts) do
      capacity = Keyword.get(opts, :capacity, 100)
      refill_rate = Keyword.get(opts, :refill_rate, 10)
      {:ok, %{buckets: %{}, capacity: capacity, refill_rate: refill_rate}}
    end

    @impl GenServer
    def handle_call({:allow, key, cost}, _from, state) do
      bucket = Map.get_lazy(state.buckets, key, fn -> RateLimiter.Bucket.new(state.capacity, state.refill_rate) end)
      bucket = RateLimiter.Bucket.refill(bucket)
      case RateLimiter.Bucket.consume(bucket, cost) do
        {:ok, updated} -> {:reply, true, %{state | buckets: Map.put(state.buckets, key, updated)}}
        {:error, :rate_limited} -> {:reply, false, %{state | buckets: Map.put(state.buckets, key, bucket)}}
      end
    end

    @impl GenServer
    def handle_cast({:reset, key}, state), do: {:noreply, %{state | buckets: Map.delete(state.buckets, key)}}

    defp default_bucket(state), do: RateLimiter.Bucket.new(state.capacity, state.refill_rate)
  end
  '''
end
