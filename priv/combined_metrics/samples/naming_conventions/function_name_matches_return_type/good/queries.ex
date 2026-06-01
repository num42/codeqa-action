defmodule Queries do
  # get_* returns data
  def get_user(user_id) do
    fetch_from_db(:users, user_id)
  end

  # is_*/has_*/can_* return booleans
  def is_user_active?(user_id) do
    user = fetch_from_db(:users, user_id)
    user.status == :active
  end

  # list_* returns a collection
  def list_orders(user_id) do
    [fetch_from_db(:orders, {:latest, user_id})]
  end

  # has_* returns a boolean
  def has_permissions?(user_id) do
    perms = fetch_from_db(:permissions, user_id)
    length(perms.scopes) > 0
  end

  # can_* returns a boolean
  def can_edit?(user_id) do
    user = fetch_from_db(:users, user_id)
    user.role in [:admin, :editor]
  end

  # create_* returns the new entity
  def create_session(user_id) do
    {:ok, %{user_id: user_id, token: "tok_#{user_id}"}}
  end

  # list_* returns a collection
  def list_products_by_category(category) do
    [
      %{id: 1, name: "Widget", category: category},
      %{id: 2, name: "Gadget", category: category}
    ]
  end

  defp fetch_from_db(:users, id), do: %{id: id, name: "User #{id}", status: :active, role: :member}
  defp fetch_from_db(:orders, {:latest, uid}), do: %{id: 99, user_id: uid, status: :shipped}
  defp fetch_from_db(:permissions, uid), do: %{user_id: uid, scopes: [:read, :write]}
end
