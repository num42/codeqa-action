defmodule AuthToken do
  @moduledoc "Issues, validates, and revokes authentication tokens"

  def issue(nil, _scopes), do: {:error, :user_required}
  def issue(_user, []), do: {:error, :scopes_required}

  def issue(user, scopes) do
    token = generate_token(user.id)
    store_token(token, scopes)
    {:ok, %{token: token, user_id: user.id, scopes: scopes}}
  end

  def validate(token) do
    case lookup_token(token) do
      nil ->
        {:error, :unknown_token}

      %{expires_at: exp} = record ->
        check_expiry(record, exp)
    end
  end

  defp check_expiry(record, exp) do
    if expired?(exp) do
      {:error, :expired}
    else
      {:ok, record}
    end
  end

  def authorize(%{scopes: scopes}, required) when is_atom(required) do
    if required in scopes do
      :ok
    else
      {:error, :forbidden}
    end
  end

  def revoke(%{token: token}), do: revoke(token)

  def revoke(token) when is_binary(token) do
    delete_token(token)
    {:ok, :revoked}
  end

  defp generate_token(user_id), do: "tok_#{user_id}_#{System.unique_integer([:positive])}"
  defp store_token(_token, _scopes), do: :ok
  defp lookup_token(_token), do: nil
  defp delete_token(_token), do: :ok
  defp expired?(_exp), do: false
end
