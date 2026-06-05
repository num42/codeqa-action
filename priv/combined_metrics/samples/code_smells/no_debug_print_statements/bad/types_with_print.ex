defmodule MyApp.Storage.Adapter do
  @moduledoc """
  Storage adapter behaviour — BAD: a debug print sits in the helper that
  sits alongside the callback declarations.
  """

  @type key :: String.t()
  @type value :: binary()

  @callback get(key()) :: {:ok, value()} | {:error, term()}
  @callback put(key(), value()) :: :ok | {:error, term()}

  def describe(impl) do
    IO.inspect(impl, label: "storage adapter impl")
    "#{inspect(impl)} adapter"
  end
end
