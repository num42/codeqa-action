defmodule RateLimiter do
  @moduledoc """
  Rate limiting logic for API endpoints.
  """

  def check_rate(user_id, action) do
    key = "#{user_id}:#{action}"
    count = get_count(key)

    cond do
      action == :api_call and count >= 100 ->
        {:error, :rate_limited}
      action == :login and count >= 5 ->
        {:error, :rate_limited}
      action == :export and count >= 10 ->
        {:error, :rate_limited}
      true ->
        increment_count(key)
        :ok
    end
  end

  def session_valid?(created_at) do
    age_seconds = DateTime.diff(DateTime.utc_now(), created_at)
    age_seconds < 3600
  end

  def token_expired?(issued_at) do
    age_seconds = DateTime.diff(DateTime.utc_now(), issued_at)
    age_seconds > 86400
  end

  def compute_backoff(attempt) do
    min(1000 * :math.pow(2, attempt), 30_000)
  end

  def charge_credits(user_id, action) do
    cost =
      case action do
        :api_call -> 1
        :export -> 10
        :bulk_import -> 50
        :report -> 25
      end

    balance = get_balance(user_id)

    if balance >= cost do
      deduct_credits(user_id, cost)
      :ok
    else
      {:error, :insufficient_credits}
    end
  end

  def apply_rate_penalty(user_id, violation_count) do
    penalty_seconds =
      cond do
        violation_count >= 10 -> 86400
        violation_count >= 5 -> 3600
        violation_count >= 3 -> 300
        true -> 60
      end

    lock_until = DateTime.add(DateTime.utc_now(), penalty_seconds)
    set_lock(user_id, lock_until)
  end

  def calculate_overage_fee(requests_made, limit) do
    overage = max(0, requests_made - limit)
    overage * 0.15
  end

  def burst_allowed?(user_id) do
    recent = count_recent_requests(user_id, 60)
    recent < 200
  end

  def cleanup_old_entries do
    cutoff = DateTime.add(DateTime.utc_now(), -604800)
    delete_entries_before(cutoff)
  end

  defp get_count(_key), do: 0
  defp increment_count(_key), do: :ok
  defp get_balance(_user_id), do: 100
  defp deduct_credits(_user_id, _amount), do: :ok
  defp set_lock(_user_id, _until), do: :ok
  defp count_recent_requests(_user_id, _seconds), do: 0
  defp delete_entries_before(_cutoff), do: :ok
end
