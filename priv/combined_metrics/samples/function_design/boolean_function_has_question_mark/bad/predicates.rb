class User
  def is_admin
    role == :admin
  end

  def check_active
    !banned && confirmed_at.present?
  end

  def get_verified
    email_verified && phone_verified
  end

  def check_expired
    expires_at < Time.now
  end

  def is_visible
    published && !archived
  end

  def check_blank
    name.nil? || name.strip.empty?
  end
end
