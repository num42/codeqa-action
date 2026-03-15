defmodule Accounts.UserTest do
  @moduledoc """
  User tests — GOOD: every test has at least one meaningful assertion.
  """
  use ExUnit.Case

  test "create/1 returns {:ok, user} with assigned id" do
    attrs = %{name: "Alice", email: "alice@example.com", role: :member}
    assert {:ok, user} = Accounts.User.create(attrs)
    assert user.name == "Alice"
    assert is_integer(user.id)
  end

  test "validate/1 returns {:error, :invalid_email} for malformed email" do
    user = %{name: "Bob", email: "not-an-email", role: :guest}
    assert {:error, :invalid_email} = Accounts.User.validate(user)
  end

  test "create/1 succeeds with admin role" do
    assert {:ok, user} = Accounts.User.create(%{name: "Carol", email: "carol@example.com", role: :admin})
    assert user.role == :admin
  end

  test "update/2 merges new attributes onto existing user" do
    user = %{id: 1, name: "Dave", email: "dave@example.com"}
    assert {:ok, updated} = Accounts.User.update(user, %{name: "David"})
    assert updated.name == "David"
    assert updated.email == "dave@example.com"
  end

  test "deactivate/1 sets active to false" do
    user = %{id: 2, name: "Eve", active: true}
    assert {:ok, updated} = Accounts.User.deactivate(user)
    assert updated.active == false
  end

  test "delete/1 returns :ok" do
    user = %{id: 3, name: "Frank"}
    assert :ok = Accounts.User.delete(user)
  end
end

defmodule Accounts.User do
  def create(attrs), do: {:ok, Map.put(attrs, :id, System.unique_integer([:positive]))}
  def validate(%{email: email} = user) when is_binary(email), do: {:ok, user}
  def validate(_), do: {:error, :invalid_email}
  def update(user, attrs), do: {:ok, Map.merge(user, attrs)}
  def deactivate(user), do: {:ok, Map.put(user, :active, false)}
  def delete(_user), do: :ok
end
