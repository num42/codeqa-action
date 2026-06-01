defmodule UserTest do
  use ExUnit.Case, async: true

  describe "create_user/1" do
    test "creates user when attrs are valid" do
      attrs = %{name: "Alice", email: "alice@example.com", role: :member}
      assert {:ok, user} = User.create(attrs)
      assert user.name == "Alice"
    end

    test "returns error when email is missing" do
      attrs = %{name: "Alice", role: :member}
      assert {:error, changeset} = User.create(attrs)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "returns error when email is already taken" do
      attrs = %{name: "Bob", email: "bob@example.com", role: :member}
      {:ok, _} = User.create(attrs)
      assert {:error, changeset} = User.create(attrs)
      assert "has already been taken" in errors_on(changeset).email
    end
  end

  describe "update_user/2" do
    test "updates user name when attrs are valid" do
      user = %{id: 1, name: "Alice", email: "alice@example.com"}
      assert {:ok, updated} = User.update(user, %{name: "Alicia"})
      assert updated.name == "Alicia"
    end

    test "rejects invalid role value" do
      user = %{id: 1, name: "Alice", email: "alice@example.com", role: :member}
      assert {:error, _changeset} = User.update(user, %{role: :superuser})
    end
  end

  describe "deactivate_user/1" do
    test "deactivates an active user" do
      user = %{id: 1, status: :active}
      assert {:ok, deactivated} = User.deactivate(user)
      assert deactivated.status == :inactive
    end

    test "returns error when user is already inactive" do
      user = %{id: 1, status: :inactive}
      assert {:error, :already_inactive} = User.deactivate(user)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
