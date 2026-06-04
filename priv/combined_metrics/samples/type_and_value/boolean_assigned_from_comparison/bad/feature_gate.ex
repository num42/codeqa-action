defmodule Platform.FeatureGate do
  @moduledoc """
  Feature gating — BAD: feature flags derived via nested if/case returning
  true/false rather than assigning the comparison result directly.
  """

  def gate(user, feature) do
    enabled_globally =
      case feature.rollout do
        :all -> true
        _ -> false
      end

    in_beta_group =
      if user.beta_member do
        if feature.rollout == :beta do
          true
        else
          false
        end
      else
        false
      end

    allowed =
      cond do
        enabled_globally -> true
        in_beta_group -> true
        true -> false
      end

    %{enabled_globally: enabled_globally, in_beta_group: in_beta_group, allowed: allowed}
  end

  def tier_flags(user) do
    is_pro =
      case user.tier do
        :pro -> true
        :enterprise -> true
        _ -> false
      end

    trial_active =
      if user.trial_ends_at != nil do
        if user.trial_days_left > 0 do
          true
        else
          false
        end
      else
        false
      end

    %{pro: is_pro, trial_active: trial_active}
  end
end
