defmodule MyApp.Accounts do
  @moduledoc """
  User account management.
  """

  alias MyApp.Accounts.User
  alias MyApp.Repo

  # Bad: eight positional parameters. Callers must remember the exact order.
  # What is the difference between `role` and `plan`? Is `org_id` before or after?
  # Easy to accidentally swap `team_id` and `org_id`.
  @spec register(String.t(), String.t(), String.t(), atom(), atom(), integer(), integer(), DateTime.t()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register(name, email, password, role, plan, org_id, team_id, trial_expires_at) do
    %User{}
    |> User.registration_changeset(%{
      name: name,
      email: email,
      password: password,
      role: role,
      plan: plan,
      organization_id: org_id,
      team_id: team_id,
      trial_expires_at: trial_expires_at
    })
    |> Repo.insert()
  end

  # Bad: sending an email with six individual string parameters
  @spec send_welcome_email(String.t(), String.t(), String.t(), String.t(), String.t(), String.t()) :: :ok
  def send_welcome_email(to_email, user_name, org_name, plan_name, support_email, login_url) do
    MyApp.Mailer.deliver(%{
      to: to_email,
      subject: "Welcome, #{user_name}!",
      template: :welcome,
      assigns: %{
        name: user_name,
        org: org_name,
        plan: plan_name,
        support: support_email,
        url: login_url
      }
    })

    :ok
  end

  # Bad: updating a user with many individual named fields — no grouping
  @spec update_profile(User.t(), String.t(), String.t(), String.t(), String.t(), boolean()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_profile(%User{} = user, name, bio, website, timezone, notifications_enabled) do
    user
    |> User.profile_changeset(%{
      name: name,
      bio: bio,
      website: website,
      timezone: timezone,
      notifications_enabled: notifications_enabled
    })
    |> Repo.update()
  end
end
