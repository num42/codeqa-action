defmodule FeatureFlags.Bad do
  @moduledoc """
  Feature-flag gating with negated boolean names.
  BAD: is_not_enabled, not_in_cohort, no_rollout — negated gates invert the logic.
  """

  @spec enabled?(map(), map()) :: boolean()
  def enabled?(flag, user) do
    is_not_enabled = flag.state != :on
    not_in_cohort = user.id not in flag.cohort
    no_rollout = flag.rollout_percent < bucket(user)

    not (is_not_enabled or (not_in_cohort and no_rollout))
  end

  @spec visible?(map(), map()) :: boolean()
  def visible?(flag, user) do
    is_not_published = flag.published_at == nil
    is_not_beta_user = user.tier != :beta

    not (is_not_published or (not flag.public and is_not_beta_user))
  end

  @spec stale?(map()) :: boolean()
  def stale?(flag) do
    is_not_fully_rolled = flag.rollout_percent != 100
    is_not_old = flag.age_days <= 90

    not (is_not_fully_rolled or is_not_old)
  end

  defp bucket(user), do: rem(user.id, 100)
end
