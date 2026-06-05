defmodule MyApp.Storage.Adapter do
  @moduledoc """
  Storage adapter behaviour and shared types — GOOD: callbacks and typespecs
  only. A behaviour module declares an interface; it never prints.
  """

  @type key :: String.t()
  @type value :: binary()
  @type opts :: keyword()
  @type error :: {:error, :not_found | :unavailable | term()}

  @callback get(key()) :: {:ok, value()} | error()
  @callback put(key(), value(), opts()) :: :ok | error()
  @callback delete(key()) :: :ok | error()
  @callback list(prefix :: key()) :: {:ok, [key()]} | error()

  @optional_callbacks list: 1
end
