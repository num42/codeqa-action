defmodule Auth.AccessPolicy do
  @moduledoc """
  Access policy evaluation — GOOD: authorization booleans assigned directly
  from comparison expressions and predicate calls.
  """

  def evaluate(actor, resource) do
    is_owner = actor.id == resource.owner_id
    is_admin = actor.role in [:admin, :superadmin]
    is_public = resource.visibility == :public
    is_locked = resource.locked and not is_admin

    %{
      can_read: is_public or is_owner or is_admin,
      can_write: (is_owner or is_admin) and not is_locked,
      can_delete: is_admin or (is_owner and resource.deletable)
    }
  end

  def quota_status(account) do
    over_limit = account.usage > account.quota
    near_limit = account.usage >= account.quota * 0.9 and not over_limit
    suspended = account.status == :suspended

    %{over_limit: over_limit, near_limit: near_limit, suspended: suspended}
  end

  def session_valid?(session, now) do
    not_expired = DateTime.compare(session.expires_at, now) == :gt
    same_origin = session.origin == session.bound_origin
    not_revoked = session.revoked_at == nil

    not_expired and same_origin and not_revoked
  end
end
