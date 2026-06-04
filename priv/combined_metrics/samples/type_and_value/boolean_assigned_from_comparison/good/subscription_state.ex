defmodule Billing.SubscriptionState do
  @moduledoc """
  Subscription state flags — GOOD: each boolean assigned directly from a
  comparison or predicate, keeping the derivation flat and readable.
  """

  def snapshot(sub, now) do
    active = sub.status == :active
    trialing = sub.status == :trialing and DateTime.compare(sub.trial_ends_at, now) == :gt
    past_due = sub.status == :past_due
    cancellable = active and not sub.cancel_at_period_end

    %{active: active, trialing: trialing, past_due: past_due, cancellable: cancellable}
  end

  def renews?(sub, now) do
    auto_renew = sub.auto_renew == true
    within_window = DateTime.diff(sub.current_period_end, now, :day) <= 3
    has_payment = sub.payment_method_id != nil

    auto_renew and within_window and has_payment
  end

  def usage_flags(sub) do
    over_seats = sub.active_seats > sub.seat_limit
    near_seats = sub.active_seats >= sub.seat_limit - 1 and not over_seats
    metered = sub.plan_type == :metered

    %{over_seats: over_seats, near_seats: near_seats, metered: metered}
  end
end
