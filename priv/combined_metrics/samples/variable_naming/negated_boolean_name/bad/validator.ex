defmodule Validator.Bad do
  @moduledoc """
  Form and data validation using negated boolean variable names.
  BAD: is_not_valid, not_active, is_disabled, no_access, not_found — double negatives obscure logic.
  """

  @spec validate_user(map()) :: {:ok, map()} | {:error, list(String.t())}
  def validate_user(user) do
    is_not_valid_email = not valid_email?(user.email)
    not_active_account = user.status != :active
    is_not_empty_name = user.name == "" or is_nil(user.name)

    errors =
      []
      |> maybe_add("Email is invalid", is_not_valid_email)
      |> maybe_add("Account is not active", not_active_account)
      |> maybe_add("Name cannot be blank", is_not_empty_name)

    if errors == [], do: {:ok, user}, else: {:error, errors}
  end

  @spec check_access(map(), String.t()) :: boolean()
  def check_access(user, resource) do
    no_access = user.role not in [:admin, :editor]
    is_disabled = user.status == :disabled
    not_found = not resource_exists?(resource)

    not (no_access or is_disabled or not_found)
  end

  @spec validate_payment(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_payment(payment) do
    is_not_valid_amount = payment.amount <= 0
    not_supported_currency = payment.currency not in ["USD", "EUR", "GBP"]
    is_expired_card = card_expired?(payment.card)

    cond do
      is_not_valid_amount -> {:error, "Amount must be positive"}
      not_supported_currency -> {:error, "Currency not supported"}
      is_expired_card -> {:error, "Card has expired"}
      true -> {:ok, payment}
    end
  end

  @spec validate_password(String.t()) :: {:ok, String.t()} | {:error, list(String.t())}
  def validate_password(password) do
    is_not_long_enough = String.length(password) < 8
    is_not_complex_enough = not has_special_char?(password)
    no_uppercase = not has_uppercase?(password)
    no_digit = not has_digit?(password)

    errors =
      []
      |> maybe_add("Must be at least 8 characters", is_not_long_enough)
      |> maybe_add("Must contain a special character", is_not_complex_enough)
      |> maybe_add("Must contain an uppercase letter", no_uppercase)
      |> maybe_add("Must contain a digit", no_digit)

    if errors == [], do: {:ok, password}, else: {:error, errors}
  end

  @spec validate_form(map()) :: {:ok, map()} | {:error, map()}
  def validate_form(form) do
    is_not_valid_email = not valid_email?(form[:email] || "")
    not_accepted_terms = not form[:terms_accepted]
    is_not_empty_message = is_nil(form[:message]) or String.trim(form[:message]) == ""

    errors = %{}
    errors = if is_not_valid_email, do: Map.put(errors, :email, "Invalid email"), else: errors
    errors = if not_accepted_terms, do: Map.put(errors, :terms, "Must accept terms"), else: errors
    errors = if is_not_empty_message, do: Map.put(errors, :message, "Message is required"), else: errors

    if map_size(errors) == 0, do: {:ok, form}, else: {:error, errors}
  end

  defp valid_email?(email), do: String.contains?(email, "@")
  defp resource_exists?(_resource), do: true
  defp card_expired?(_card), do: false
  defp has_special_char?(pw), do: Regex.match?(~r/[!@#$%^&*]/, pw)
  defp has_uppercase?(pw), do: Regex.match?(~r/[A-Z]/, pw)
  defp has_digit?(pw), do: Regex.match?(~r/\d/, pw)
  defp maybe_add(errors, msg, true), do: [msg | errors]
  defp maybe_add(errors, _msg, false), do: errors
end
