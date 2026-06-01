defmodule MyApp.Subscriptions do
  # Bad: no @moduledoc at all — public module with no documentation
  # The module purpose, lifecycle, and conventions are undocumented.

  alias MyApp.Subscriptions.{Subscription, Plan}
  alias MyApp.Repo

  # Bad: using a plain comment instead of @doc for a public function.
  # Consumers cannot use `h MyApp.Subscriptions.create/2` in IEx.
  # Creates a new subscription
  @spec create(integer(), Plan.t()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def create(customer_id, %Plan{} = plan) do
    initial_status = if plan.trial_days > 0, do: :trialing, else: :active

    trial_ends_at =
      if plan.trial_days > 0 do
        DateTime.add(DateTime.utc_now(), plan.trial_days * 86_400, :second)
      end

    %Subscription{}
    |> Subscription.changeset(%{
      customer_id: customer_id,
      plan_id: plan.id,
      status: initial_status,
      trial_ends_at: trial_ends_at
    })
    |> Repo.insert()
  end

  @doc """
  Cancels the subscription.

  Implementation note: we first check if the changeset is valid by calling
  Subscription.changeset/2, then call Repo.update/1. The Subscription schema
  has a :cancelled_at field that gets set here. We also emit a telemetry event
  by calling :telemetry.execute/3 with the [:my_app, :subscriptions, :transitioned]
  event name. The metadata map has :from and :to keys. The Repo is aliased at the
  top of this module. We use DateTime.utc_now() for the timestamp.
  """
  # Bad: @doc describes the implementation in exhaustive detail — not the contract.
  # The doc should explain what the function does for callers, not how it works internally.
  @spec cancel(Subscription.t()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def cancel(%Subscription{status: :cancelled} = sub), do: {:ok, sub}

  def cancel(%Subscription{} = sub) do
    sub
    |> Subscription.changeset(%{status: :cancelled, cancelled_at: DateTime.utc_now()})
    |> Repo.update()
  end

  # Bad: no @doc on a public function — leaves callers guessing
  @spec reactivate(Subscription.t()) :: {:ok, Subscription.t()} | {:error, atom()}
  def reactivate(%Subscription{} = sub) do
    sub
    |> Subscription.changeset(%{status: :active, cancelled_at: nil})
    |> Repo.update()
  end
end
