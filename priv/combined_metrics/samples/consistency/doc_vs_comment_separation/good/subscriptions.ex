defmodule MyApp.Subscriptions do
  @moduledoc """
  Public API for managing customer subscriptions.

  Subscriptions move through the following lifecycle:
  `:trialing` -> `:active` -> `:past_due` -> `:cancelled`

  All state transitions emit a telemetry event under
  `[:my_app, :subscriptions, :transitioned]`.
  """

  alias MyApp.Subscriptions.{Subscription, Plan}
  alias MyApp.Repo

  @doc """
  Creates a new subscription for the given customer on the specified plan.

  Returns `{:ok, subscription}` on success, or `{:error, changeset}` when
  validation fails (e.g. the customer already has an active subscription).
  """
  @spec create(integer(), Plan.t()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def create(customer_id, %Plan{} = plan) do
    # Determine initial status: new customers start in a trial period
    initial_status = if plan.trial_days > 0, do: :trialing, else: :active

    # Compute trial end date; nil when the plan has no trial
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
  Cancels a subscription immediately.

  If the subscription is already cancelled this is a no-op and
  `{:ok, subscription}` is still returned.
  """
  @spec cancel(Subscription.t()) :: {:ok, Subscription.t()} | {:error, Ecto.Changeset.t()}
  def cancel(%Subscription{status: :cancelled} = sub), do: {:ok, sub}

  def cancel(%Subscription{} = sub) do
    sub
    |> Subscription.changeset(%{status: :cancelled, cancelled_at: DateTime.utc_now()})
    |> Repo.update()
    |> tap(fn
      {:ok, updated} ->
        # Emit telemetry so billing can react to the cancellation
        :telemetry.execute([:my_app, :subscriptions, :transitioned], %{}, %{
          from: sub.status,
          to: updated.status
        })

      _ ->
        :ok
    end)
  end
end
