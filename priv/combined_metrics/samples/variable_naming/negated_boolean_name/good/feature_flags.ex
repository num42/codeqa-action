defmodule FeatureFlags.Good do
  @moduledoc """
  Feature-flag gating with positive boolean names.
  GOOD: is_enabled, has_rollout, is_in_cohort — affirmative gate conditions.
  """

  @spec enabled?(map(), map()) :: boolean()
  def enabled?(flag, user) do
    is_enabled = flag.state == :on
    is_in_cohort = user.id in flag.cohort
    has_rollout = flag.rollout_percent >= bucket(user)

    is_enabled and (is_in_cohort or has_rollout)
  end

  @spec visible?(map(), map()) :: boolean()
  def visible?(flag, user) do
    is_published = flag.published_at != nil
    is_beta_user = user.tier == :beta

    is_published and (flag.public or is_beta_user)
  end

  @spec stale?(map()) :: boolean()
  def stale?(flag) do
    is_fully_rolled = flag.rollout_percent == 100
    is_old = flag.age_days > 90

    is_fully_rolled and is_old
  end

  defp bucket(user), do: rem(user.id, 100)
end
