defmodule Auth.SessionTest do
  @moduledoc """
  Auth tests — BAD: test names are vague and give no indication of expected behavior.
  """
  use ExUnit.Case

  test "test 1" do
    assert Auth.Session.login("alice@example.com", "secret") == {:ok, "token_alice"}
  end

  test "works" do
    assert Auth.Session.login("bob@example.com", "wrongpass") == {:error, :invalid_credentials}
  end

  test "test user" do
    assert Auth.Session.logout("token_alice") == :ok
  end

  test "it works fine" do
    assert Auth.Session.verify("token_alice") == {:ok, %{email: "alice@example.com"}}
  end

  test "bad token" do
    assert Auth.Session.verify("garbage") == {:error, :invalid_token}
  end

  test "refresh" do
    assert Auth.Session.refresh("token_alice") == {:ok, "token_alice_new"}
  end

  test "test expired" do
    assert Auth.Session.verify("expired_token") == {:error, :token_expired}
  end

  test "stuff" do
    assert Auth.Session.login("", "") == {:error, :invalid_credentials}
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
