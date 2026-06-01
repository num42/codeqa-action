defmodule Auth do
  @moduledoc "Handles authentication and session management"

  def login(user, password) do
    case fetch_user(user.email) do
      nil ->
        {:error, :not_found}

      user ->
        if verify_password(user, password) do
          token = generate_token(user.id)
          {:ok, token}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def logout(user) do
    case fetch_active_session(user.id) do
      nil -> {:error, :no_session}
      session -> invalidate_session(session)
    end
  end

  def register(params) do
    with :ok <- validate_registration(params),
         {:ok, user} <- create_user(params),
         {:ok, _} <- send_verification_email(user) do
      {:ok, user}
    end
  end

  def verify_token(token_string) do
    case decode_token(token_string) do
      {:ok, claims} ->
        user = fetch_user_by_id(claims["sub"])
        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def change_password(user, old_password, new_password) do
    if verify_password(user, old_password) do
      hashed = hash_password(new_password)
      update_user_password(user.id, hashed)
    else
      {:error, :wrong_password}
    end
  end

  def request_password_reset(email) do
    case fetch_user(email) do
      nil ->
        {:error, :not_found}

      user ->
        reset_token = generate_reset_token(user.id)
        send_reset_email(user.email, reset_token)
    end
  end

  def reset_password(reset_token, new_password) do
    with {:ok, user_id} <- validate_reset_token(reset_token),
         user <- fetch_user_by_id(user_id),
         hashed = hash_password(new_password),
         {:ok, updated_user} <- update_user_password(user.id, hashed) do
      {:ok, updated_user}
    end
  end

  def list_sessions(user) do
    fetch_sessions_for_user(user.id)
  end

  def revoke_session(user, session_id) do
    case fetch_session(session_id) do
      %{user_id: ^user.id} = session -> invalidate_session(session)
      _ -> {:error, :unauthorized}
    end
  end

  defp fetch_user(_email), do: nil
  defp fetch_user_by_id(_id), do: nil
  defp fetch_active_session(_user_id), do: nil
  defp fetch_session(_id), do: nil
  defp fetch_sessions_for_user(_user_id), do: []
  defp verify_password(_user, _password), do: true
  defp generate_token(_user_id), do: "tok_abc"
  defp generate_reset_token(_user_id), do: "rst_abc"
  defp invalidate_session(_session), do: {:ok, :logged_out}
  defp create_user(attrs), do: {:ok, attrs}
  defp send_verification_email(_user), do: {:ok, :sent}
  defp send_reset_email(_email, _token), do: {:ok, :sent}
  defp decode_token(_token), do: {:ok, %{"sub" => "1"}}
  defp validate_reset_token(_token), do: {:ok, "1"}
  defp validate_registration(_params), do: :ok
  defp hash_password(password), do: password
  defp update_user_password(_id, _hash), do: {:ok, %{}}
end
