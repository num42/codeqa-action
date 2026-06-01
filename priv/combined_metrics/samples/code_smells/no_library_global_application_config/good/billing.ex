defmodule Acme.Billing do
  @moduledoc """
  Billing library. All configuration is passed as explicit function
  arguments rather than read from `Application.get_env/2`.
  This makes the library usable in any application without side effects.
  """

  defmodule Config do
    @moduledoc "Configuration struct for the Acme.Billing client."
    @enforce_keys [:api_key, :base_url]
    defstruct [:api_key, :base_url, timeout_ms: 5_000, retry_count: 3]

    @type t :: %__MODULE__{
      api_key: String.t(),
      base_url: String.t(),
      timeout_ms: pos_integer(),
      retry_count: non_neg_integer()
    }
  end

  @doc """
  Creates a charge using the provided configuration.
  Config is passed explicitly — the library does not read global app env.
  """
  @spec create_charge(Config.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_charge(%Config{} = config, params) do
    url = "#{config.base_url}/charges"
    headers = [{"Authorization", "Bearer #{config.api_key}"}]
    options = [timeout: config.timeout_ms, recv_timeout: config.timeout_ms]

    case HTTPoison.post(url, Jason.encode!(params), headers, options) do
      {:ok, %{status_code: 201, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, {:network_error, reason}}
    end
  end

  @doc """
  Lists recent charges. Configuration is explicit.
  """
  @spec list_charges(Config.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_charges(%Config{} = config, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    url = "#{config.base_url}/charges?limit=#{limit}"
    headers = [{"Authorization", "Bearer #{config.api_key}"}]

    case HTTPoison.get(url, headers, timeout: config.timeout_ms) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, {:network_error, reason}}
    end
  end
end
