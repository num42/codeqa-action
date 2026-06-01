defmodule Validator.Good do
  @moduledoc """
  Form and data validation using positive boolean variable names.
  GOOD: is_valid, is_active, is_enabled, has_access, is_found — positive names read naturally.
  """

  @spec validate_user(map()) :: {:ok, map()} | {:error, list(String.t())}
  def validate_user(user) do
    is_valid_email = valid_email?(user.email)
    is_active_account = user.status == :active
    has_name = not (user.name == "" or is_nil(user.name))

    errors =
      []
      |> maybe_add("Email is invalid", not is_valid_email)
      |> maybe_add("Account is not active", not is_active_account)
      |> maybe_add("Name cannot be blank", not has_name)

    if errors == [], do: {:ok, user}, else: {:error, errors}
  end

  @spec check_access(map(), String.t()) :: boolean()
  def check_access(user, resource) do
    has_access = user.role in [:admin, :editor]
    is_enabled = user.status != :disabled
    is_found = resource_exists?(resource)

    has_access and is_enabled and is_found
  end

  @spec validate_payment(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_payment(payment) do
    is_valid_amount = payment.amount > 0
    is_supported_currency = payment.currency in ["USD", "EUR", "GBP"]
    is_valid_card = not card_expired?(payment.card)

    cond do
      not is_valid_amount -> {:error, "Amount must be positive"}
      not is_supported_currency -> {:error, "Currency not supported"}
      not is_valid_card -> {:error, "Card has expired"}
      true -> {:ok, payment}
    end
  end

  @spec validate_password(String.t()) :: {:ok, String.t()} | {:error, list(String.t())}
  def validate_password(password) do
    is_long_enough = String.length(password) >= 8
    is_complex_enough = has_special_char?(password)
    has_uppercase = has_uppercase_char?(password)
    has_digit = has_digit_char?(password)

    errors =
      []
      |> maybe_add("Must be at least 8 characters", not is_long_enough)
      |> maybe_add("Must contain a special character", not is_complex_enough)
      |> maybe_add("Must contain an uppercase letter", not has_uppercase)
      |> maybe_add("Must contain a digit", not has_digit)

    if errors == [], do: {:ok, password}, else: {:error, errors}
  end

  @spec validate_form(map()) :: {:ok, map()} | {:error, map()}
  def validate_form(form) do
    is_valid_email = valid_email?(form[:email] || "")
    has_accepted_terms = form[:terms_accepted] == true
    has_message = not (is_nil(form[:message]) or String.trim(form[:message] || "") == "")

    errors = %{}
    errors = if not is_valid_email, do: Map.put(errors, :email, "Invalid email"), else: errors
    errors = if not has_accepted_terms, do: Map.put(errors, :terms, "Must accept terms"), else: errors
    errors = if not has_message, do: Map.put(errors, :message, "Message is required"), else: errors

    if map_size(errors) == 0, do: {:ok, form}, else: {:error, errors}
  end

  defp valid_email?(email), do: String.contains?(email, "@")
  defp resource_exists?(_resource), do: true
  defp card_expired?(_card), do: false
  defp has_special_char?(pw), do: Regex.match?(~r/[!@#$%^&*]/, pw)
  defp has_uppercase_char?(pw), do: Regex.match?(~r/[A-Z]/, pw)
  defp has_digit_char?(pw), do: Regex.match?(~r/\d/, pw)
  defp maybe_add(errors, msg, true), do: [msg | errors]
  defp maybe_add(errors, _msg, false), do: errors
end
