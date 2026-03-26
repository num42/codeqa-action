defmodule MyApp.Subscriptions do
  @moduledoc """
  Manages customer subscriptions. Predicate functions end with `?`
  and guard-compatible checks use the `is_` prefix.
  """

  alias MyApp.Subscriptions.Subscription

  @doc """
  Returns true if the subscription is currently active.
  """
  @spec active?(Subscription.t()) :: boolean()
  def active?(%Subscription{status: :active, expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  def active?(%Subscription{}), do: false

  @doc """
  Returns true if the subscription is on a paid plan.
  """
  @spec paid?(%Subscription{}) :: boolean()
  def paid?(%Subscription{plan: plan}), do: plan != :free

  @doc """
  Returns true if the subscription has exceeded its usage quota.
  """
  @spec over_quota?(%Subscription{}) :: boolean()
  def over_quota?(%Subscription{used: used, quota: quota}), do: used >= quota

  @doc """
  Returns true if the subscription is in a trial period.
  """
  @spec trialing?(%Subscription{}) :: boolean()
  def trialing?(%Subscription{status: :trialing}), do: true
  def trialing?(%Subscription{}), do: false

  @doc """
  Guard-compatible check for a valid subscription map. Uses `is_` prefix
  per Elixir convention for guard-safe predicates.
  """
  defguard is_subscription(value) when is_struct(value, Subscription)

  @doc """
  Returns true if the subscription will expire within the given number of days.
  """
  @spec expiring_soon?(%Subscription{}, non_neg_integer()) :: boolean()
  def expiring_soon?(%Subscription{expires_at: expires_at}, days) do
    threshold = DateTime.add(DateTime.utc_now(), days * 86_400, :second)
    DateTime.compare(expires_at, threshold) == :lt
  end

  @doc """
  Returns true if the subscription can be upgraded to a higher tier.
  """
  @spec upgradeable?(%Subscription{}) :: boolean()
  def upgradeable?(%Subscription{plan: :enterprise}), do: false
  def upgradeable?(%Subscription{}), do: true

  @doc """
  Returns true if the subscription has auto-renewal enabled.
  """
  @spec auto_renews?(%Subscription{}) :: boolean()
  def auto_renews?(%Subscription{auto_renew: auto_renew}), do: auto_renew == true
end
