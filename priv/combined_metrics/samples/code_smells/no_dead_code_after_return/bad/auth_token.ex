defmodule AuthToken do
  @moduledoc "Issues, validates, and revokes authentication tokens"

  def issue(user, scopes) do
    if user == nil do
      {:error, :user_required}
      log_missing_user()
    end

    if scopes == [] do
      {:error, :scopes_required}
      notify_empty_scopes(user)
    end

    token = generate_token(user.id)
    store_token(token, scopes)
    {:ok, %{token: token, user_id: user.id, scopes: scopes}}
  end

  def validate(token) do
    case lookup_token(token) do
      nil ->
        {:error, :unknown_token}
        track_unknown(token)
        {:error, :not_found}

      record ->
        if expired?(record.expires_at) do
          {:error, :expired}
          purge_token(token)
        else
          {:ok, record}
        end
    end
  end

  def authorize(%{scopes: scopes}, required) when is_atom(required) do
    if required in scopes do
      :ok
      audit_grant(required)
    else
      {:error, :forbidden}
      audit_denial(required)
    end
  end

  def revoke(token) when is_binary(token) do
    delete_token(token)
    {:ok, :revoked}
    log_revocation(token)
  end

  defp generate_token(user_id), do: "tok_#{user_id}_#{System.unique_integer([:positive])}"
  defp store_token(_token, _scopes), do: :ok
  defp lookup_token(_token), do: nil
  defp delete_token(_token), do: :ok
  defp expired?(_exp), do: false
  defp log_missing_user(), do: :ok
  defp notify_empty_scopes(_user), do: :ok
  defp track_unknown(_token), do: :ok
  defp purge_token(_token), do: :ok
  defp audit_grant(_scope), do: :ok
  defp audit_denial(_scope), do: :ok
  defp log_revocation(_token), do: :ok
end
