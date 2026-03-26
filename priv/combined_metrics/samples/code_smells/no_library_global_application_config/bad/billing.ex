defmodule Acme.Billing do
  @moduledoc """
  Billing library.
  """

  # Bad: reads configuration from the global application environment.
  # This couples the library to a specific OTP app name and config key.
  # The library cannot be used without configuring `:acme_billing` in config.exs,
  # and it cannot be used with different configs simultaneously (e.g., multiple accounts).

  @doc """
  Creates a charge. Reads API key and base URL from Application env.
  """
  @spec create_charge(map()) :: {:ok, map()} | {:error, term()}
  def create_charge(params) do
    # Bad: tight coupling to global config
    api_key = Application.get_env(:acme_billing, :api_key) ||
      raise "Acme.Billing: :api_key not configured"

    base_url = Application.get_env(:acme_billing, :base_url, "https://api.acmebilling.com")
    timeout = Application.get_env(:acme_billing, :timeout_ms, 5_000)

    url = "#{base_url}/charges"
    headers = [{"Authorization", "Bearer #{api_key}"}]
    options = [timeout: timeout, recv_timeout: timeout]

    case HTTPoison.post(url, Jason.encode!(params), headers, options) do
      {:ok, %{status_code: 201, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, {:network_error, reason}}
    end
  end

  @doc """
  Lists recent charges. Also reads from Application env.
  """
  @spec list_charges(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_charges(opts \\ []) do
    # Bad: same global config dependency repeated in every function
    api_key = Application.get_env(:acme_billing, :api_key) ||
      raise "Acme.Billing: :api_key not configured"

    base_url = Application.get_env(:acme_billing, :base_url, "https://api.acmebilling.com")
    timeout = Application.get_env(:acme_billing, :timeout_ms, 5_000)
    retry = Application.get_env(:acme_billing, :retry_count, 3)

    limit = Keyword.get(opts, :limit, 20)
    url = "#{base_url}/charges?limit=#{limit}"
    headers = [{"Authorization", "Bearer #{api_key}"}]

    case HTTPoison.get(url, headers, timeout: timeout, recv_timeout: timeout) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, Jason.decode!(body)}
      {:ok, %{status_code: status}} -> {:error, {:http_error, status}}
      {:error, reason} when retry > 0 -> list_charges(opts)
      {:error, reason} -> {:error, {:network_error, reason}}
    end
  end
end
