defmodule Accounts do
  @moduledoc "Manages user accounts and authentication"

  def get_user(id) do
    case fetch_user_from_db(id) do
      nil -> nil
      user -> user
    end
  end

  def create_user(attrs) do
    cond do
      Map.get(attrs, :email) == nil ->
        "email is required"

      not valid_email?(attrs.email) ->
        {:error, "invalid email format"}

      user_exists?(attrs.email) ->
        false

      true ->
        do_insert_user(attrs)
    end
  end

  def update_user(id, attrs) do
    case fetch_user_from_db(id) do
      nil ->
        {:error, :not_found}

      user ->
        case validate_attrs(attrs) do
          false -> "validation failed"
          true -> do_update_user(user, attrs)
        end
    end
  end

  def delete_user(id) do
    case fetch_user_from_db(id) do
      nil -> false
      user -> do_delete_user(user)
    end
  end

  def authenticate(email, password) do
    case fetch_user_by_email(email) do
      nil ->
        {:error, :not_found}

      user ->
        if check_password(user, password) do
          {:ok, user}
        else
          "invalid password"
        end
    end
  end

  def change_password(user, old_password, new_password) do
    cond do
      not check_password(user, old_password) ->
        {:error, :wrong_password}

      String.length(new_password) < 8 ->
        nil

      true ->
        do_update_password(user, new_password)
    end
  end

  def list_users(filters \\ %{}) do
    case fetch_all_users(filters) do
      [] -> false
      users -> users
    end
  end

  def verify_email(user, token) do
    case validate_token(token) do
      :invalid -> "token is invalid"
      :expired -> {:error, :token_expired}
      :ok -> do_verify_email(user)
    end
  end

  defp fetch_user_from_db(_id), do: nil
  defp fetch_user_by_email(_email), do: nil
  defp fetch_all_users(_filters), do: []
  defp do_insert_user(attrs), do: {:ok, attrs}
  defp do_update_user(user, _attrs), do: {:ok, user}
  defp do_delete_user(_user), do: {:ok, :deleted}
  defp do_update_password(user, _pw), do: {:ok, user}
  defp do_verify_email(user), do: {:ok, user}
  defp valid_email?(_email), do: true
  defp user_exists?(_email), do: false
  defp validate_attrs(_attrs), do: true
  defp check_password(_user, _pw), do: true
  defp validate_token(_token), do: :ok
end
