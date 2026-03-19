defmodule UserHandler do
  @moduledoc """
  Handles everything user-related: registration, email, payments, and audit.
  """

  require Logger

  def register_user(attrs) do
    with {:ok, _} <- validate_registration(attrs),
         {:ok, user} <- insert_user(attrs),
         :ok <- send_welcome_email(user),
         :ok <- create_free_trial_subscription(user),
         :ok <- log_audit_event(:user_registered, user) do
      {:ok, user}
    end
  end

  def update_user(id, attrs) do
    case find_user(id) do
      nil -> {:error, :not_found}
      user ->
        updated = Map.merge(user, attrs)
        save_user(updated)
        send_profile_updated_email(updated)
        log_audit_event(:user_updated, updated)
        {:ok, updated}
    end
  end

  def delete_user(id) do
    case find_user(id) do
      nil -> {:error, :not_found}
      user ->
        cancel_subscription(user)
        send_goodbye_email(user)
        remove_user(user)
        log_audit_event(:user_deleted, user)
        :ok
    end
  end

  def send_welcome_email(user) do
    body = "Hi #{user.name}, welcome to our platform!"
    dispatch_email(user.email, "Welcome!", body)
  end

  def send_profile_updated_email(user) do
    body = "Hi #{user.name}, your profile has been updated."
    dispatch_email(user.email, "Profile Updated", body)
  end

  def send_goodbye_email(user) do
    body = "Goodbye #{user.name}, your account has been deleted."
    dispatch_email(user.email, "Account Deleted", body)
  end

  def create_free_trial_subscription(user) do
    sub = %{user_id: user.id, plan: :free_trial, expires_at: trial_expiry()}
    save_subscription(sub)
    charge_initial_setup_fee(user, 0)
    :ok
  end

  def cancel_subscription(user) do
    case find_subscription(user.id) do
      nil -> :ok
      sub ->
        update_subscription(sub, %{status: :cancelled})
        process_prorated_refund(user, sub)
        :ok
    end
  end

  def charge_initial_setup_fee(user, amount) do
    if amount > 0 do
      call_payment_gateway(user.payment_method, amount)
    else
      :ok
    end
  end

  def process_prorated_refund(_user, _sub) do
    :ok
  end

  def log_audit_event(event, user) do
    Logger.info("AUDIT: #{event} for user #{user.id} at #{DateTime.utc_now()}")
    write_audit_log(%{event: event, user_id: user.id, timestamp: DateTime.utc_now()})
  end

  defp validate_registration(attrs) do
    if Map.has_key?(attrs, :email) and Map.has_key?(attrs, :password) do
      {:ok, attrs}
    else
      {:error, :missing_fields}
    end
  end

  defp find_user(_id), do: nil
  defp insert_user(attrs), do: {:ok, Map.put(attrs, :id, :rand.uniform(1000))}
  defp save_user(_user), do: :ok
  defp remove_user(_user), do: :ok
  defp dispatch_email(_to, _subject, _body), do: :ok
  defp save_subscription(_sub), do: :ok
  defp find_subscription(_user_id), do: nil
  defp update_subscription(_sub, _attrs), do: :ok
  defp call_payment_gateway(_method, _amount), do: :ok
  defp write_audit_log(_entry), do: :ok
  defp trial_expiry, do: DateTime.add(DateTime.utc_now(), 30 * 86_400)
end
