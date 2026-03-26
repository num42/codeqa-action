defmodule Accounts.UserTest do
  @moduledoc """
  User tests — BAD: test blocks with setup code but no assertions.
  """
  use ExUnit.Case

  test "create user" do
    attrs = %{name: "Alice", email: "alice@example.com", role: :member}
    # calls the function but never asserts on the result
    Accounts.User.create(attrs)
  end

  test "user email validation" do
    user = %{name: "Bob", email: "not-an-email", role: :guest}
    # assigns result but never asserts
    _result = Accounts.User.validate(user)
  end

  test "user with admin role" do
    user = Accounts.User.create(%{name: "Carol", email: "carol@example.com", role: :admin})
    # inspects but never asserts
    IO.inspect(user)
  end

  test "update user name" do
    user = %{id: 1, name: "Dave", email: "dave@example.com"}
    # sets up the update but no assertion follows
    Accounts.User.update(user, %{name: "David"})
    :ok
  end

  test "deactivate user" do
    user = %{id: 2, name: "Eve", active: true}
    updated = Accounts.User.deactivate(user)
    # logs rather than asserts
    IO.puts("Deactivated: #{inspect(updated)}")
  end

  test "user roles" do
    roles = [:admin, :member, :guest]
    Enum.each(roles, fn role ->
      Accounts.User.create(%{name: "Test", email: "t@t.com", role: role})
    end)
    # no assertion — just iterates
  end

  test "delete user" do
    user = %{id: 3, name: "Frank"}
    Accounts.User.delete(user)
    # returns truthy but never checked
    true
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
