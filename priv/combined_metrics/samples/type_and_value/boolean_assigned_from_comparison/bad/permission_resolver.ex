defmodule Auth.PermissionResolver do
  @moduledoc """
  Permission resolution — BAD: boolean flags derived through nested if/cond/case
  branches returning true/false instead of direct comparisons.
  """

  def resolve(actor, resource) do
    is_owner =
      if actor.id == resource.owner_id do
        true
      else
        false
      end

    is_admin =
      cond do
        actor.role == :admin -> true
        actor.role == :superadmin -> true
        true -> false
      end

    can_edit =
      if is_owner do
        if not resource.locked do
          true
        else
          false
        end
      else
        if is_admin do
          true
        else
          false
        end
      end

    %{owner: is_owner, admin: is_admin, can_edit: can_edit}
  end

  def visibility_flags(resource) do
    is_public =
      case resource.visibility do
        :public -> true
        _ -> false
      end

    is_restricted =
      if resource.visibility == :internal do
        true
      else
        false
      end

    %{public: is_public, restricted: is_restricted}
  end
end
