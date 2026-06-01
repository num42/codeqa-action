defmodule Access.Roles do
  @moduledoc """
  Role/permission management — GOOD: atoms used for roles, statuses, and named constants.
  """

  @roles [:superadmin, :admin, :moderator, :member, :guest]
  @verified_statuses [:active_premium, :active_standard]
  @full_access_permissions [:all_access, :read_write, :read_write_no_delete]

  def assign_role(user, role) do
    permissions = permissions_for(role)
    %{user | role: role, permissions: permissions}
  end

  defp permissions_for(:superadmin), do: :all_access
  defp permissions_for(:admin), do: :read_write_no_delete
  defp permissions_for(:moderator), do: :read_write_flag
  defp permissions_for(:member), do: :read_write
  defp permissions_for(:guest), do: :read_only

  def can_access?(user, resource) do
    if user.account_status in @verified_statuses do
      check_resource_permission(user.permissions, resource)
    else
      false
    end
  end

  defp check_resource_permission(permissions, _resource) do
    permissions in @full_access_permissions
  end

  def get_subscription_tier(user) do
    case user.plan do
      :free -> "Free"
      :basic -> "Basic"
      :pro -> "Pro"
      :enterprise -> "Enterprise"
      _ -> "Unknown"
    end
  end

  def set_account_status(user, event) do
    new_status =
      case event do
        :email_confirmed -> :active_standard
        :upgrade_to_premium -> :active_premium
        :account_suspended -> :suspended
        :account_closed -> :closed
        _ -> :pending_review
      end

    %{user | account_status: new_status}
  end

  def valid_role?(role), do: role in @roles
end
