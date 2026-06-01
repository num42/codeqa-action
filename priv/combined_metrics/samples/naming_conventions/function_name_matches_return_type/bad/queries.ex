defmodule Queries do
  # get_* returns a boolean instead of data
  def get_user_active(user_id) do
    user = fetch_from_db(:users, user_id)
    user.status == :active
  end

  # is_* returns data instead of a boolean
  def is_user(user_id) do
    fetch_from_db(:users, user_id)
  end

  # list_* returns a single item instead of a collection
  def list_latest_order(user_id) do
    fetch_from_db(:orders, {:latest, user_id})
  end

  # has_* returns data instead of a boolean
  def has_permissions(user_id) do
    fetch_from_db(:permissions, user_id)
  end

  # can_* returns data instead of a boolean
  def can_role(user_id) do
    user = fetch_from_db(:users, user_id)
    user.role
  end

  # create_* returns a boolean instead of the new entity
  def create_new_session(user_id) do
    _session = %{user_id: user_id, token: "tok_#{user_id}"}
    true
  end

  # get_* returns a collection instead of a single item
  def get_products(category) do
    [
      %{id: 1, name: "Widget", category: category},
      %{id: 2, name: "Gadget", category: category}
    ]
  end

  defp fetch_from_db(:users, id), do: %{id: id, name: "User #{id}", status: :active, role: :member}
  defp fetch_from_db(:orders, {:latest, uid}), do: %{id: 99, user_id: uid, status: :shipped}
  defp fetch_from_db(:permissions, uid), do: %{user_id: uid, scopes: [:read, :write]}
end
