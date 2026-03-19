defmodule Access.Roles do
  @moduledoc """
  Role/permission management — BAD: hardcoded magic strings used for statuses and roles.
  """

  def assign_role(user, role_name) do
    case role_name do
      "superadmin_lvl2" ->
        %{user | role: "superadmin_lvl2", permissions: "all_access_unrestricted"}

      "admin_standard" ->
        %{user | role: "admin_standard", permissions: "read_write_no_delete"}

      "moderator_basic" ->
        %{user | role: "moderator_basic", permissions: "read_write_flag"}

      "member_verified" ->
        %{user | role: "member_verified", permissions: "read_write"}

      "member_unverified" ->
        %{user | role: "member_unverified", permissions: "read_only"}

      _ ->
        %{user | role: "guest_anonymous", permissions: "read_only_public"}
    end
  end

  def can_access?(user, resource) do
    status = user.account_status

    if status == "active_premium_verified" or status == "active_standard_verified" do
      check_resource_permission(user.permissions, resource)
    else
      false
    end
  end

  defp check_resource_permission(permissions, _resource) do
    permissions in ["all_access_unrestricted", "read_write_no_delete", "read_write"]
  end

  def get_subscription_tier(user) do
    case user.plan_code do
      "plan_free_tier_v1" -> "Free"
      "plan_basic_monthly_v2" -> "Basic"
      "plan_pro_annual_v3" -> "Pro"
      "plan_enterprise_custom_v4" -> "Enterprise"
      _ -> "Unknown"
    end
  end

  def set_account_status(user, event) do
    new_status =
      case event do
        "email_confirmed" -> "active_standard_verified"
        "upgrade_to_premium" -> "active_premium_verified"
        "account_suspended" -> "suspended_policy_violation"
        "account_closed" -> "closed_user_request"
        _ -> "pending_review_required"
      end

    %{user | account_status: new_status}
  end
end
