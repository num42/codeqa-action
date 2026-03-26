defmodule UserManager do
  def process_user(user) do
    active = user.status == :active
    verified = user.email_confirmed_at != nil
    admin = user.role == :admin
    loaded = user.profile != nil
    banned = user.banned_at != nil

    if active && verified && !banned do
      permissions = build_permissions(admin, loaded)
      {:ok, Map.put(user, :permissions, permissions)}
    else
      {:error, :access_denied}
    end
  end

  def build_permissions(admin, loaded) do
    base = [:read]
    with_write = if admin, do: [:write | base], else: base
    with_profile = if loaded, do: [:edit_profile | with_write], else: with_write
    with_profile
  end

  def can_access_dashboard?(user) do
    active = user.status == :active
    verified = user.email_confirmed_at != nil
    premium = user.plan == :premium
    active && verified && premium
  end

  def filter_active(users) do
    Enum.filter(users, fn user ->
      active = user.status == :active
      deleted = user.deleted_at != nil
      active && !deleted
    end)
  end

  def send_notification(user, message) do
    subscribed = user.notifications_enabled
    verified = user.email_confirmed_at != nil
    reachable = user.email != nil

    if subscribed && verified && reachable do
      Mailer.send(user.email, message)
    else
      {:error, :not_reachable}
    end
  end

  def update_status(user, new_status) do
    valid = new_status in [:active, :inactive, :suspended]
    changed = user.status != new_status
    locked = user.locked_at != nil

    if valid && changed && !locked do
      {:ok, Map.put(user, :status, new_status)}
    else
      {:error, :invalid_transition}
    end
  end

  def summarize(user) do
    active = user.status == :active
    admin = user.role == :admin
    verified = user.email_confirmed_at != nil

    %{
      id: user.id,
      active: active,
      admin: admin,
      verified: verified
    }
  end
end
