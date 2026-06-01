defmodule UserRegistration do
  @moduledoc """
  Handles new user registration: validation and account creation only.

  Side effects (email, billing, audit) are delegated to their respective
  context modules and triggered via events after successful registration.
  """

  alias UserRegistration.{Repo, User}

  @spec register(map()) :: {:ok, User.t()} | {:error, :missing_fields | :email_taken | String.t()}
  def register(attrs) do
    with {:ok, validated} <- validate(attrs),
         :ok <- ensure_email_available(validated.email),
         {:ok, user} <- Repo.insert(User, validated) do
      {:ok, user}
    end
  end

  @spec validate(map()) :: {:ok, map()} | {:error, :missing_fields}
  def validate(attrs) do
    required = [:email, :password, :name]
    missing = Enum.reject(required, &Map.has_key?(attrs, &1))

    if missing == [] do
      {:ok, attrs}
    else
      {:error, :missing_fields}
    end
  end

  @spec ensure_email_available(String.t()) :: :ok | {:error, :email_taken}
  def ensure_email_available(email) do
    case Repo.find_by(User, email: email) do
      nil -> :ok
      _existing -> {:error, :email_taken}
    end
  end

  @spec valid_password?(String.t()) :: boolean()
  def valid_password?(password) do
    String.length(password) >= 8 and
      String.match?(password, ~r/[A-Z]/) and
      String.match?(password, ~r/[0-9]/)
  end

  @spec normalize_email(String.t()) :: String.t()
  def normalize_email(email) do
    email
    |> String.trim()
    |> String.downcase()
  end
end
