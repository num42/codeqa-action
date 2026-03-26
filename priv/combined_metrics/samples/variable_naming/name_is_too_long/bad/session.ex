defmodule Session.Bad do
  @moduledoc """
  Session and auth management with excessively long variable names.
  BAD: variables like the_currently_authenticated_and_logged_in_user_object are unwieldy.
  """

  @spec start_session(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def start_session(email_address_of_the_user, plain_text_password_entered_by_the_user) do
    the_user_account_that_was_looked_up_from_the_database = fetch_user_by_email(email_address_of_the_user)

    if verify_password(plain_text_password_entered_by_the_user, the_user_account_that_was_looked_up_from_the_database.password_hash) do
      the_newly_generated_session_token_string = generate_secure_random_session_token()
      the_session_expiry_timestamp_in_utc = DateTime.add(DateTime.utc_now(), 86_400, :second)

      {:ok, %{
        token: the_newly_generated_session_token_string,
        expires_at: the_session_expiry_timestamp_in_utc,
        user_id: the_user_account_that_was_looked_up_from_the_database.id
      }}
    else
      {:error, "Invalid credentials"}
    end
  end

  @spec validate_session(String.t()) :: {:ok, map()} | {:error, String.t()}
  def validate_session(the_session_token_string_provided_by_the_client) do
    the_session_record_retrieved_from_the_database =
      lookup_session_in_database(the_session_token_string_provided_by_the_client)

    the_current_date_and_time_in_utc_timezone = DateTime.utc_now()

    if DateTime.before?(the_current_date_and_time_in_utc_timezone, the_session_record_retrieved_from_the_database.expires_at) do
      {:ok, the_session_record_retrieved_from_the_database}
    else
      {:error, "Session expired"}
    end
  end

  @spec refresh_session(String.t()) :: {:ok, map()} | {:error, String.t()}
  def refresh_session(the_existing_session_token_that_needs_to_be_refreshed) do
    with {:ok, the_current_session_data_from_the_database} <-
           validate_session(the_existing_session_token_that_needs_to_be_refreshed) do
      the_new_session_token_that_replaces_the_old_one = generate_secure_random_session_token()
      the_updated_expiry_time_for_the_refreshed_session = DateTime.add(DateTime.utc_now(), 86_400, :second)

      {:ok, %{
        token: the_new_session_token_that_replaces_the_old_one,
        expires_at: the_updated_expiry_time_for_the_refreshed_session,
        user_id: the_current_session_data_from_the_database.user_id
      }}
    end
  end

  @spec list_active_sessions(integer()) :: list(map())
  def list_active_sessions(the_unique_identifier_of_the_user_account) do
    the_maximum_allowed_number_of_retry_attempts_before_giving_up = 3
    the_complete_list_of_all_sessions_belonging_to_the_specified_user =
      fetch_all_sessions_for_user(the_unique_identifier_of_the_user_account, the_maximum_allowed_number_of_retry_attempts_before_giving_up)

    the_current_timestamp_used_to_filter_expired_sessions = DateTime.utc_now()

    Enum.filter(the_complete_list_of_all_sessions_belonging_to_the_specified_user, fn each_individual_session_record ->
      DateTime.before?(the_current_timestamp_used_to_filter_expired_sessions, each_individual_session_record.expires_at)
    end)
  end

  defp fetch_user_by_email(email), do: %{id: 1, email: email, password_hash: "hash"}
  defp verify_password(password, _hash), do: String.length(password) > 0
  defp generate_secure_random_session_token, do: :crypto.strong_rand_bytes(32) |> Base.encode64()
  defp lookup_session_in_database(_token), do: %{user_id: 1, expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)}
  defp fetch_all_sessions_for_user(_id, _retries), do: []
end
