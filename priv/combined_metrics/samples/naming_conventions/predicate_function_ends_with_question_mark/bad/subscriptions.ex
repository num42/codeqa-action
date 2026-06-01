defmodule MyApp.Subscriptions do
  @moduledoc """
  Manages customer subscriptions.
  """

  alias MyApp.Subscriptions.Subscription

  # Bad: predicate function missing `?` suffix
  @spec active(Subscription.t()) :: boolean()
  def active(%Subscription{status: :active, expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  def active(%Subscription{}), do: false

  # Bad: predicate named `is_paid` without being a guard
  @spec is_paid(%Subscription{}) :: boolean()
  def is_paid(%Subscription{plan: plan}), do: plan != :free

  # Bad: returns boolean but named like a command, not a predicate
  @spec check_quota(%Subscription{}) :: boolean()
  def check_quota(%Subscription{used: used, quota: quota}), do: used >= quota

  # Bad: using `has_` prefix instead of ending with `?`
  @spec has_trial(%Subscription{}) :: boolean()
  def has_trial(%Subscription{status: :trialing}), do: true
  def has_trial(%Subscription{}), do: false

  # Bad: `valid` instead of `valid?`
  @spec valid(map()) :: boolean()
  def valid(%{plan: plan, status: status}) do
    plan in [:free, :starter, :pro, :enterprise] and
      status in [:active, :trialing, :past_due]
  end

  def valid(_), do: false

  # Bad: using `can_upgrade` instead of `upgradeable?`
  @spec can_upgrade(%Subscription{}) :: boolean()
  def can_upgrade(%Subscription{plan: :enterprise}), do: false
  def can_upgrade(%Subscription{}), do: true

  # Bad: using `get_auto_renew` for a boolean check
  @spec get_auto_renew(%Subscription{}) :: boolean()
  def get_auto_renew(%Subscription{auto_renew: auto_renew}), do: auto_renew == true
end
