defmodule Auth do
  @moduledoc "Handles authentication and session management"

  def login(account, password) do
    case fetch_user(account.email) do
      nil ->
        {:error, :not_found}

      u ->
        if verify_password(u, password) do
          token = generate_token(u.id)
          {:ok, token}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  def logout(usr) do
    case fetch_active_session(usr.id) do
      nil -> {:error, :no_session}
      session -> invalidate_session(session)
    end
  end

  def register(params) do
    with :ok <- validate_registration(params),
         {:ok, new_account} <- create_user(params),
         {:ok, _} <- send_verification_email(new_account) do
      {:ok, new_account}
    end
  end

  def verify_token(token_string) do
    case decode_token(token_string) do
      {:ok, claims} ->
        account = fetch_user_by_id(claims["sub"])
        {:ok, account}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def change_password(u, old_pw, new_pw) do
    if verify_password(u, old_pw) do
      hashed = hash_password(new_pw)
      update_user_password(u.id, hashed)
    else
      {:error, :wrong_password}
    end
  end

  def request_password_reset(email_address) do
    case fetch_user(email_address) do
      nil ->
        {:error, :not_found}

      account ->
        reset_token = generate_reset_token(account.id)
        send_reset_email(account.email, reset_token)
    end
  end

  def reset_password(reset_token, new_pw) do
    with {:ok, usr_id} <- validate_reset_token(reset_token),
         account <- fetch_user_by_id(usr_id),
         hashed = hash_password(new_pw),
         {:ok, updated} <- update_user_password(account.id, hashed) do
      {:ok, updated}
    end
  end

  def list_sessions(account) do
    fetch_sessions_for_user(account.id)
  end

  def revoke_session(u, session_id) do
    case fetch_session(session_id) do
      %{user_id: ^u.id} = session -> invalidate_session(session)
      _ -> {:error, :unauthorized}
    end
  end

  defp fetch_user(_email), do: nil
  defp fetch_user_by_id(_id), do: nil
  defp fetch_active_session(_user_id), do: nil
  defp fetch_session(_id), do: nil
  defp fetch_sessions_for_user(_user_id), do: []
  defp verify_password(_user, _pw), do: true
  defp generate_token(_user_id), do: "tok_abc"
  defp generate_reset_token(_user_id), do: "rst_abc"
  defp invalidate_session(_session), do: {:ok, :logged_out}
  defp create_user(attrs), do: {:ok, attrs}
  defp send_verification_email(_user), do: {:ok, :sent}
  defp send_reset_email(_email, _token), do: {:ok, :sent}
  defp decode_token(_token), do: {:ok, %{"sub" => "1"}}
  defp validate_reset_token(_token), do: {:ok, "1"}
  defp validate_registration(_params), do: :ok
  defp hash_password(pw), do: pw
  defp update_user_password(_id, _hash), do: {:ok, %{}}
end
