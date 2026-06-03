defmodule AccessControl do
  def authorize(%{role: :admin}, _resource, _action), do: :ok

  def authorize(%{role: :owner, id: id}, %{owner_id: id}, _action), do: :ok

  def authorize(%{role: :member} = user, resource, :read) do
    if shared_with?(resource, user), do: :ok, else: {:error, :forbidden}
  end

  def authorize(%{role: :member} = user, resource, :write) do
    with :ok <- ensure_editor(user),
         :ok <- ensure_not_locked(resource) do
      :ok
    end
  end

  def authorize(%{role: :guest}, _resource, :read), do: :ok
  def authorize(%{role: :guest}, _resource, _action), do: {:error, :forbidden}
  def authorize(_user, _resource, _action), do: {:error, :forbidden}

  defp ensure_editor(%{permissions: perms}) do
    if :edit in perms, do: :ok, else: {:error, :forbidden}
  end

  defp ensure_not_locked(%{locked: true}), do: {:error, :locked}
  defp ensure_not_locked(_resource), do: :ok

  defp shared_with?(%{shared_user_ids: ids}, %{id: id}), do: id in ids
  defp shared_with?(_resource, _user), do: false
end
