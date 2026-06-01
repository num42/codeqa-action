defmodule UserManager do
  def create_user(attrs) do
    with :ok <- validate_attrs(attrs),
         {:ok, user} <- insert_user(attrs) do
      {:ok, user}
    end
  end

  def update_user(user, attrs) do
    with :ok <- validate_attrs(attrs),
         {:ok, updated} <- persist_update(user, attrs) do
      {:ok, updated}
    end
  end

  def deactivate_user(user) do
    case user.status do
      :active -> {:ok, %{user | status: :inactive}}
      :inactive -> {:error, :already_inactive}
    end
  end

  def find_by_email(email) do
    case lookup_email(email) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def list_active_users do
    [
      %{id: 1, name: "Alice", email: "alice@example.com", status: :active},
      %{id: 2, name: "Bob", email: "bob@example.com", status: :active}
    ]
  end

  defp validate_attrs(%{email: email}) when is_binary(email), do: :ok
  defp validate_attrs(_), do: {:error, :invalid_attrs}

  defp insert_user(attrs) do
    {:ok, Map.merge(%{id: System.unique_integer([:positive])}, attrs)}
  end

  defp persist_update(user, attrs) do
    {:ok, Map.merge(user, attrs)}
  end

  defp lookup_email("alice@example.com"), do: %{id: 1, email: "alice@example.com", status: :active}
  defp lookup_email(_), do: nil
end
