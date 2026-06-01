# Session and auth management with concise, clear variable names.
# GOOD: current_user, max_retries, selected_product — short but descriptive.

class SessionGood
  def start_session(email, password)
    user = fetch_user_by_email(email)
    is_valid = verify_password(password, user[:password_hash])

    raise 'Invalid credentials' unless is_valid

    token = generate_session_token
    expires_at = Time.now + 86_400

    { token: token, expires_at: expires_at, user_id: user[:id] }
  end

  def validate_session(token)
    session = lookup_session(token)
    now = Time.now

    raise 'Session expired' if now > session[:expires_at]

    session
  end

  def refresh_session(old_token)
    current_session = validate_session(old_token)
    new_token = generate_session_token
    expires_at = Time.now + 86_400

    { token: new_token, expires_at: expires_at, user_id: current_session[:user_id] }
  end

  def list_active_sessions(user_id)
    max_retries = 3
    sessions = fetch_all_sessions(user_id, max_retries)
    now = Time.now

    sessions.select { |session| session[:expires_at] > now }
  end

  def current_user(token)
    session = validate_session(token)
    fetch_user_by_id(session[:user_id])
  end

  def invalidate_all_sessions(user_id)
    active_sessions = list_active_sessions(user_id)
    active_sessions.each { |session| delete_session(session[:id]) }
  end

  private

  def fetch_user_by_email(email) = { id: 1, email: email, password_hash: 'hash' }
  def fetch_user_by_id(id) = { id: id }
  def verify_password(password, _hash) = password.length > 0
  def generate_session_token = SecureRandom.hex(32)
  def lookup_session(_token) = { user_id: 1, expires_at: Time.now + 3600 }
  def fetch_all_sessions(_user_id, _max_retries) = []
  def delete_session(_session_id) = nil
end
