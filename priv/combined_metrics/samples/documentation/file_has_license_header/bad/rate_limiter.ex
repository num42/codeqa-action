defmodule MyApp.RateLimiter do
  @moduledoc """
  Sliding-window rate limiter backed by an in-memory bucket map.

  Tracks request timestamps per key and rejects calls that exceed the
  configured limit within the rolling window.
  """

  defstruct limit: 100, window_ms: 60_000, buckets: %{}

  @type t :: %__MODULE__{
          limit: pos_integer(),
          window_ms: pos_integer(),
          buckets: %{optional(String.t()) => [integer()]}
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      limit: Keyword.get(opts, :limit, 100),
      window_ms: Keyword.get(opts, :window_ms, 60_000)
    }
  end

  @spec check(t(), String.t(), integer()) :: {:ok | :denied, t()}
  def check(%__MODULE__{} = limiter, key, now \\ System.monotonic_time(:millisecond)) do
    cutoff = now - limiter.window_ms
    recent = limiter.buckets |> Map.get(key, []) |> Enum.filter(&(&1 > cutoff))

    if length(recent) < limiter.limit do
      {:ok, put_in(limiter.buckets[key], [now | recent])}
    else
      {:denied, put_in(limiter.buckets[key], recent)}
    end
  end
end
