defmodule MyApp.Billing.SubscriptionRenewal do
  alias MyApp.Billing

  @moduledoc """
  Service that renews due subscriptions.
  All data access and side effects go through the Billing context.
  """

  def run(now \\ DateTime.utc_now()) do
    now
    |> Billing.due_subscriptions()
    |> Enum.map(&renew/1)
  end

  defp renew(subscription) do
    with {:ok, charge} <- Billing.charge_subscription(subscription),
         {:ok, renewed} <- Billing.extend_period(subscription, charge) do
      Billing.notify_renewed(renewed)
      {:ok, renewed}
    else
      {:error, reason} ->
        Billing.notify_failure(subscription, reason)
        {:error, reason}
    end
  end
end
