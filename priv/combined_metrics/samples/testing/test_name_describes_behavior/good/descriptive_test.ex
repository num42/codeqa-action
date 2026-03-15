defmodule Auth.SessionTest do
  @moduledoc """
  Auth tests — GOOD: test names describe the expected behavior and conditions.
  """
  use ExUnit.Case

  describe "login/2" do
    test "returns {:ok, token} when credentials are valid" do
      assert {:ok, token} = Auth.Session.login("alice@example.com", "secret")
      assert is_binary(token)
    end

    test "returns {:error, :invalid_credentials} when password is wrong" do
      assert Auth.Session.login("bob@example.com", "wrongpass") == {:error, :invalid_credentials}
    end

    test "returns {:error, :invalid_credentials} when email and password are empty" do
      assert Auth.Session.login("", "") == {:error, :invalid_credentials}
    end
  end

  describe "logout/1" do
    test "returns :ok for any valid token" do
      assert Auth.Session.logout("token_alice") == :ok
    end
  end

  describe "verify/1" do
    test "returns {:ok, user_info} for a valid token" do
      assert Auth.Session.verify("token_alice") == {:ok, %{email: "alice@example.com"}}
    end

    test "returns {:error, :token_expired} for an expired token" do
      assert Auth.Session.verify("expired_token") == {:error, :token_expired}
    end

    test "returns {:error, :invalid_token} for a malformed token" do
      assert Auth.Session.verify("garbage") == {:error, :invalid_token}
    end
  end

  describe "refresh/1" do
    test "returns {:ok, new_token} when token is valid and active" do
      assert Auth.Session.refresh("token_alice") == {:ok, "token_alice_new"}
    end

    test "returns {:error, :invalid_token} when token does not exist" do
      assert Auth.Session.refresh("nonexistent") == {:error, :invalid_token}
    end
  end
end

defmodule Auth.Session do
  def login("alice@example.com", "secret"), do: {:ok, "token_alice"}
  def login(_, _), do: {:error, :invalid_credentials}
  def logout(_token), do: :ok
  def verify("token_alice"), do: {:ok, %{email: "alice@example.com"}}
  def verify("expired_token"), do: {:error, :token_expired}
  def verify(_), do: {:error, :invalid_token}
  def refresh("token_alice"), do: {:ok, "token_alice_new"}
  def refresh(_), do: {:error, :invalid_token}
end
