# Session and auth management with excessively long variable names.
# BAD: variables like the_currently_authenticated_and_logged_in_user_object are unwieldy.

class SessionBad
  def start_session(email_address_of_the_user, plain_text_password_entered_by_the_user)
    the_user_account_that_was_looked_up_from_the_database = fetch_user_by_email(email_address_of_the_user)

    is_password_correct_and_matches_the_stored_hash = verify_password(
      plain_text_password_entered_by_the_user,
      the_user_account_that_was_looked_up_from_the_database[:password_hash]
    )

    raise 'Invalid credentials' unless is_password_correct_and_matches_the_stored_hash

    the_newly_generated_session_token_string = generate_secure_random_session_token
    the_session_expiry_timestamp_in_utc = Time.now + 86_400

    {
      token: the_newly_generated_session_token_string,
      expires_at: the_session_expiry_timestamp_in_utc,
      user_id: the_user_account_that_was_looked_up_from_the_database[:id]
    }
  end

  def validate_session(the_session_token_string_provided_by_the_client)
    the_session_record_retrieved_from_the_database =
      lookup_session_in_database(the_session_token_string_provided_by_the_client)

    the_current_date_and_time_in_utc_timezone = Time.now

    if the_current_date_and_time_in_utc_timezone > the_session_record_retrieved_from_the_database[:expires_at]
      raise 'Session expired'
    end

    the_session_record_retrieved_from_the_database
  end

  def refresh_session(the_existing_session_token_that_needs_to_be_refreshed)
    the_current_session_data_from_the_database =
      validate_session(the_existing_session_token_that_needs_to_be_refreshed)

    the_new_session_token_that_replaces_the_old_one = generate_secure_random_session_token
    the_updated_expiry_time_for_the_refreshed_session = Time.now + 86_400

    {
      token: the_new_session_token_that_replaces_the_old_one,
      expires_at: the_updated_expiry_time_for_the_refreshed_session,
      user_id: the_current_session_data_from_the_database[:user_id]
    }
  end

  def list_active_sessions(the_unique_identifier_of_the_user_account)
    the_maximum_allowed_number_of_retry_attempts_before_giving_up = 3
    the_complete_list_of_all_sessions_belonging_to_the_specified_user = fetch_all_sessions_for_user(
      the_unique_identifier_of_the_user_account,
      the_maximum_allowed_number_of_retry_attempts_before_giving_up
    )

    the_current_timestamp_used_to_filter_expired_sessions = Time.now

    the_complete_list_of_all_sessions_belonging_to_the_specified_user.select do |each_individual_session_record|
      each_individual_session_record[:expires_at] > the_current_timestamp_used_to_filter_expired_sessions
    end
  end

  def get_the_currently_authenticated_and_logged_in_user_object(the_session_token_string_provided_by_the_client)
    the_validated_session_record_from_the_database =
      validate_session(the_session_token_string_provided_by_the_client)
    fetch_user_by_id_from_the_database(the_validated_session_record_from_the_database[:user_id])
  end

  private

  def fetch_user_by_email(email) = { id: 1, email: email, password_hash: 'hash' }
  def verify_password(password, _hash) = password.length > 0
  def generate_secure_random_session_token = SecureRandom.hex(32)
  def lookup_session_in_database(_token) = { user_id: 1, expires_at: Time.now + 3600 }
  def fetch_all_sessions_for_user(_id, _retries) = []
  def fetch_user_by_id_from_the_database(id) = { id: id }
end
