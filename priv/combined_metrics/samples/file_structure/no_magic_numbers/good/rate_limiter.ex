defmodule RateLimiter do
  @moduledoc """
  Rate limiting logic for API endpoints.
  """

  @api_call_limit 100
  @login_limit 5
  @export_limit 10

  @session_ttl_seconds 3_600
  @token_ttl_seconds 86_400
  @week_in_seconds 604_800

  @max_backoff_ms 30_000
  @base_backoff_ms 1_000

  @credit_cost_api_call 1
  @credit_cost_export 10
  @credit_cost_bulk_import 50
  @credit_cost_report 25

  @penalty_minor_seconds 60
  @penalty_low_seconds 300
  @penalty_medium_seconds 3_600
  @penalty_high_seconds 86_400

  @overage_fee_per_request 0.15
  @burst_window_seconds 60
  @burst_limit 200

  def check_rate(user_id, action) do
    key = "#{user_id}:#{action}"
    count = get_count(key)

    cond do
      action == :api_call and count >= @api_call_limit ->
        {:error, :rate_limited}
      action == :login and count >= @login_limit ->
        {:error, :rate_limited}
      action == :export and count >= @export_limit ->
        {:error, :rate_limited}
      true ->
        increment_count(key)
        :ok
    end
  end

  def session_valid?(created_at) do
    age_seconds = DateTime.diff(DateTime.utc_now(), created_at)
    age_seconds < @session_ttl_seconds
  end

  def token_expired?(issued_at) do
    age_seconds = DateTime.diff(DateTime.utc_now(), issued_at)
    age_seconds > @token_ttl_seconds
  end

  def compute_backoff(attempt) do
    min(@base_backoff_ms * :math.pow(2, attempt), @max_backoff_ms)
  end

  def charge_credits(user_id, action) do
    cost = credit_cost(action)
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
        violation_count >= 10 -> @penalty_high_seconds
        violation_count >= 5 -> @penalty_medium_seconds
        violation_count >= 3 -> @penalty_low_seconds
        true -> @penalty_minor_seconds
      end

    lock_until = DateTime.add(DateTime.utc_now(), penalty_seconds)
    set_lock(user_id, lock_until)
  end

  def calculate_overage_fee(requests_made, limit) do
    overage = max(0, requests_made - limit)
    overage * @overage_fee_per_request
  end

  def burst_allowed?(user_id) do
    recent = count_recent_requests(user_id, @burst_window_seconds)
    recent < @burst_limit
  end

  def cleanup_old_entries do
    cutoff = DateTime.add(DateTime.utc_now(), -@week_in_seconds)
    delete_entries_before(cutoff)
  end

  defp credit_cost(:api_call), do: @credit_cost_api_call
  defp credit_cost(:export), do: @credit_cost_export
  defp credit_cost(:bulk_import), do: @credit_cost_bulk_import
  defp credit_cost(:report), do: @credit_cost_report

  defp get_count(_key), do: 0
  defp increment_count(_key), do: :ok
  defp get_balance(_user_id), do: 100
  defp deduct_credits(_user_id, _amount), do: :ok
  defp set_lock(_user_id, _until), do: :ok
  defp count_recent_requests(_user_id, _seconds), do: 0
  defp delete_entries_before(_cutoff), do: :ok
end
