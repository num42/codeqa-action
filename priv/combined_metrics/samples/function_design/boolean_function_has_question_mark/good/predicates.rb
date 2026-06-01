class User
  def admin?
    role == :admin
  end

  def active?
    !banned && confirmed_at.present?
  end

  def verified?
    email_verified && phone_verified
  end

  def expired?
    expires_at < Time.now
  end

  def visible?
    published && !archived
  end

  def blank?
    name.nil? || name.strip.empty?
  end
end
