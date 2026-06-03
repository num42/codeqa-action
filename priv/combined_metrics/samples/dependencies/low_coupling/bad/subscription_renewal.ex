defmodule MyApp.Billing.SubscriptionRenewal do
  import Ecto.Query

  alias MyApp.Repo
  alias MyApp.Billing.Subscription
  alias MyApp.Billing.Invoice
  alias MyApp.Accounts.User
  alias MyApp.Payments.StripeGateway
  alias MyApp.Notifications.Mailer

  @moduledoc """
  Service that renews due subscriptions.
  """

  def run(now \\ DateTime.utc_now()) do
    Repo.all(from(s in Subscription, where: s.renews_at <= ^now, preload: [:user]))
    |> Enum.map(&renew/1)
  end

  defp renew(subscription) do
    user = Repo.get!(User, subscription.user_id)

    case StripeGateway.charge(user.stripe_customer_id, subscription.amount_cents) do
      {:ok, charge} ->
        invoice =
          Repo.insert!(%Invoice{
            subscription_id: subscription.id,
            user_id: user.id,
            amount_cents: subscription.amount_cents,
            external_id: charge.id,
            status: :paid
          })

        next = DateTime.add(subscription.renews_at, 30, :day)
        changeset = Subscription.changeset(subscription, %{renews_at: next})
        {:ok, renewed} = Repo.update(changeset)

        Mailer.send_renewal_receipt(user.email, invoice)
        {:ok, renewed}

      {:error, reason} ->
        Mailer.send_payment_failure(user.email, subscription)
        {:error, reason}
    end
  end
end
