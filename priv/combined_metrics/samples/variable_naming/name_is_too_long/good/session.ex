defmodule Session.Good do
  @moduledoc """
  Session and auth management with concise, clear variable names.
  GOOD: current_user, max_retries, selected_product — short but descriptive.
  """

  @spec start_session(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def start_session(email, password) do
    user = fetch_user_by_email(email)

    if verify_password(password, user.password_hash) do
      token = generate_session_token()
      expires_at = DateTime.add(DateTime.utc_now(), 86_400, :second)

      {:ok, %{token: token, expires_at: expires_at, user_id: user.id}}
    else
      {:error, "Invalid credentials"}
    end
  end

  @spec validate_session(String.t()) :: {:ok, map()} | {:error, String.t()}
  def validate_session(token) do
    session = lookup_session(token)
    now = DateTime.utc_now()

    if DateTime.before?(now, session.expires_at) do
      {:ok, session}
    else
      {:error, "Session expired"}
    end
  end

  @spec refresh_session(String.t()) :: {:ok, map()} | {:error, String.t()}
  def refresh_session(old_token) do
    with {:ok, current_session} <- validate_session(old_token) do
      new_token = generate_session_token()
      expires_at = DateTime.add(DateTime.utc_now(), 86_400, :second)

      {:ok, %{token: new_token, expires_at: expires_at, user_id: current_session.user_id}}
    end
  end

  @spec list_active_sessions(integer()) :: list(map())
  def list_active_sessions(user_id) do
    max_retries = 3
    sessions = fetch_all_sessions(user_id, max_retries)
    now = DateTime.utc_now()

    Enum.filter(sessions, fn session ->
      DateTime.before?(now, session.expires_at)
    end)
  end

  @spec invalidate_all_sessions(integer()) :: :ok
  def invalidate_all_sessions(user_id) do
    active_sessions = list_active_sessions(user_id)
    Enum.each(active_sessions, &delete_session/1)
    :ok
  end

  @spec current_user(String.t()) :: {:ok, map()} | {:error, String.t()}
  def current_user(token) do
    with {:ok, session} <- validate_session(token) do
      user = fetch_user_by_id(session.user_id)
      {:ok, user}
    end
  end

  defp fetch_user_by_email(email), do: %{id: 1, email: email, password_hash: "hash"}
  defp fetch_user_by_id(id), do: %{id: id}
  defp verify_password(password, _hash), do: String.length(password) > 0
  defp generate_session_token, do: :crypto.strong_rand_bytes(32) |> Base.encode64()
  defp lookup_session(_token), do: %{user_id: 1, expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)}
  defp fetch_all_sessions(_user_id, _max_retries), do: []
  defp delete_session(_session), do: :ok
end
