defmodule MyApp.Accounts do
  @moduledoc """
  Manages user accounts.
  """

  alias MyApp.Accounts.User
  alias MyApp.Repo

  # Bad: bang function returns nil instead of raising
  @spec get_user!(integer()) :: User.t() | nil
  def get_user!(id) do
    Repo.get(User, id)
  end

  # Bad: bang function returns a tuple instead of raising
  @spec create_user!(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user!(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  # Bad: non-bang function raises instead of returning a tuple
  @spec update_user(User.t(), map()) :: User.t()
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update!()
  end

  # Bad: bang function swallows errors and returns nil
  @spec delete_user!(integer()) :: User.t() | nil
  def delete_user!(id) do
    case Repo.get(User, id) do
      nil -> nil
      user ->
        case Repo.delete(user) do
          {:ok, deleted} -> deleted
          {:error, _} -> nil
        end
    end
  end

  # Bad: non-bang function that raises for not-found
  @spec find_by_email(String.t()) :: User.t()
  def find_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil -> raise "User with email #{email} not found"
      user -> user
    end
  end

  # Bad: bang function silently returning an error tuple
  @spec authenticate_user!(String.t(), String.t()) :: {:ok, User.t()} | {:error, :unauthorized}
  def authenticate_user!(email, password) do
    case Repo.get_by(User, email: email) do
      nil ->
        {:error, :unauthorized}

      user ->
        if User.valid_password?(user, password) do
          {:ok, user}
        else
          {:error, :unauthorized}
        end
    end
  end
end
