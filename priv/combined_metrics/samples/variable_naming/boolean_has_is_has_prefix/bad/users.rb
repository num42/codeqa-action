class UserManager
  def process_user(user)
    active = user[:status] == :active
    verified = user[:email_confirmed_at] != nil
    admin = user[:role] == :admin
    loaded = user[:profile] != nil
    banned = user[:banned_at] != nil

    if active && verified && !banned
      permissions = build_permissions(admin, loaded)
      user.merge(permissions: permissions)
    else
      { error: :access_denied }
    end
  end

  def build_permissions(admin, loaded)
    base = [:read]
    with_write = admin ? [:write] + base : base
    with_profile = loaded ? [:edit_profile] + with_write : with_write
    with_profile
  end

  def can_access_dashboard?(user)
    active = user[:status] == :active
    verified = user[:email_confirmed_at] != nil
    premium = user[:plan] == :premium
    active && verified && premium
  end

  def filter_active(users)
    users.select do |user|
      active = user[:status] == :active
      deleted = user[:deleted_at] != nil
      active && !deleted
    end
  end

  def send_notification(user, message)
    subscribed = user[:notifications_enabled]
    verified = user[:email_confirmed_at] != nil
    reachable = user[:email] != nil

    if subscribed && verified && reachable
      Mailer.send(user[:email], message)
    else
      { error: :not_reachable }
    end
  end

  def update_status(user, new_status)
    valid = [:active, :inactive, :suspended].include?(new_status)
    changed = user[:status] != new_status
    locked = user[:locked_at] != nil

    if valid && changed && !locked
      user.merge(status: new_status)
    else
      { error: :invalid_transition }
    end
  end

  def summarize(user)
    active = user[:status] == :active
    admin = user[:role] == :admin
    verified = user[:email_confirmed_at] != nil
    { id: user[:id], active: active, admin: admin, verified: verified }
  end
end
