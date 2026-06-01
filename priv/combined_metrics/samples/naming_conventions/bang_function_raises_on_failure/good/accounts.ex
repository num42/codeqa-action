defmodule MyApp.Accounts do
  @moduledoc """
  Manages user accounts. Provides both safe tuple-returning variants
  and bang variants that raise on failure.
  """

  alias MyApp.Accounts.User
  alias MyApp.Repo

  @doc """
  Fetches a user by ID. Returns `{:ok, user}` on success or
  `{:error, :not_found}` when no user exists with the given ID.
  """
  @spec get_user(integer()) :: {:ok, User.t()} | {:error, :not_found}
  def get_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Fetches a user by ID. Raises `Ecto.NoResultsError` when no user
  exists with the given ID. Use this when the caller expects the
  record to always exist.
  """
  @spec get_user!(integer()) :: User.t()
  def get_user!(id) do
    Repo.get!(User, id)
  end

  @doc """
  Creates a new user with the given attributes. Returns `{:ok, user}`
  on success or `{:error, changeset}` on validation failure.
  """
  @spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a new user with the given attributes. Raises
  `Ecto.InvalidChangesetError` on validation failure.
  """
  @spec create_user!(map()) :: User.t()
  def create_user!(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates an existing user. Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates an existing user. Raises on failure.
  """
  @spec update_user!(User.t(), map()) :: User.t()
  def update_user!(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update!()
  end

  @doc """
  Deletes a user by ID. Returns `{:ok, user}` or `{:error, :not_found}`.
  """
  @spec delete_user(integer()) :: {:ok, User.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete_user(id) do
    with {:ok, user} <- get_user(id) do
      Repo.delete(user)
    end
  end
end
