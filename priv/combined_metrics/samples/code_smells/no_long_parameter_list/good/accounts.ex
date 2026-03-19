defmodule MyApp.Accounts do
  @moduledoc """
  User account management. Related parameters are grouped into
  structs rather than passed as long argument lists.
  """

  alias MyApp.Accounts.{User, UserRegistration}
  alias MyApp.Repo

  defmodule UserRegistration do
    @moduledoc "Encapsulates all parameters needed to register a new user."
    @enforce_keys [:email, :password, :name]
    defstruct [
      :email,
      :password,
      :name,
      :organization_id,
      :role,
      :plan,
      :invite_token,
      timezone: "UTC"
    ]
  end

  @doc """
  Registers a new user. Parameters are grouped in a `UserRegistration` struct
  rather than passed as individual arguments.
  """
  @spec register(UserRegistration.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register(%UserRegistration{} = registration) do
    %User{}
    |> User.registration_changeset(%{
      email: registration.email,
      password: registration.password,
      name: registration.name,
      organization_id: registration.organization_id,
      role: registration.role || :member,
      plan: registration.plan || :free,
      timezone: registration.timezone
    })
    |> Repo.insert()
  end

  @doc """
  Sends a welcome email. Takes the user struct rather than individual fields.
  """
  @spec send_welcome_email(User.t()) :: :ok | {:error, term()}
  def send_welcome_email(%User{} = user) do
    MyApp.Mailer.deliver(%{
      to: user.email,
      subject: "Welcome, #{user.name}!",
      template: :welcome,
      assigns: %{user: user}
    })
  end

  @doc """
  Updates a user's profile. Groups the changeable fields in a map.
  """
  @spec update_profile(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_profile(%User{} = user, attrs) when is_map(attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end
end
