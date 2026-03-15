class UserManager
  def process_user(user)
    is_active = user[:status] == :active
    is_verified = user[:email_confirmed_at] != nil
    is_admin = user[:role] == :admin
    has_profile = user[:profile] != nil
    is_banned = user[:banned_at] != nil

    if is_active && is_verified && !is_banned
      permissions = build_permissions(is_admin, has_profile)
      user.merge(permissions: permissions)
    else
      { error: :access_denied }
    end
  end

  def build_permissions(is_admin, has_profile)
    base = [:read]
    with_write = is_admin ? [:write] + base : base
    with_profile = has_profile ? [:edit_profile] + with_write : with_write
    with_profile
  end

  def can_access_dashboard?(user)
    is_active = user[:status] == :active
    is_verified = user[:email_confirmed_at] != nil
    is_premium = user[:plan] == :premium
    is_active && is_verified && is_premium
  end

  def filter_active(users)
    users.select do |user|
      is_active = user[:status] == :active
      is_deleted = user[:deleted_at] != nil
      is_active && !is_deleted
    end
  end

  def send_notification(user, message)
    has_notifications_enabled = user[:notifications_enabled]
    is_verified = user[:email_confirmed_at] != nil
    has_email = user[:email] != nil

    if has_notifications_enabled && is_verified && has_email
      Mailer.send(user[:email], message)
    else
      { error: :not_reachable }
    end
  end

  def update_status(user, new_status)
    is_valid_status = [:active, :inactive, :suspended].include?(new_status)
    has_status_changed = user[:status] != new_status
    is_locked = user[:locked_at] != nil

    if is_valid_status && has_status_changed && !is_locked
      user.merge(status: new_status)
    else
      { error: :invalid_transition }
    end
  end

  def summarize(user)
    is_active = user[:status] == :active
    is_admin = user[:role] == :admin
    is_verified = user[:email_confirmed_at] != nil
    { id: user[:id], is_active: is_active, is_admin: is_admin, is_verified: is_verified }
  end
end
