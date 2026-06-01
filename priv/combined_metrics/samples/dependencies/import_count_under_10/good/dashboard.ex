defmodule MyApp.Dashboard do
  @moduledoc """
  Dashboard aggregation module that compiles user-facing metrics
  and summaries from all subdomains.
  """

  alias MyApp.Accounts
  alias MyApp.Orders
  alias MyApp.Billing
  alias MyApp.Shipping
  alias MyApp.Notifications

  @spec summary(Accounts.User.t()) :: map()
  def summary(user) do
    %{
      orders: Orders.recent_for_user(user, limit: 5),
      invoices: Billing.open_invoices_for_user(user),
      shipments: Shipping.active_shipments_for_user(user),
      notifications: Notifications.unread_for_user(user)
    }
  end

  @spec order_count(Accounts.User.t()) :: non_neg_integer()
  def order_count(user) do
    user
    |> Orders.for_user()
    |> length()
  end

  @spec billing_status(Accounts.User.t()) :: :current | :overdue | :no_invoices
  def billing_status(user) do
    user
    |> Billing.open_invoices_for_user()
    |> determine_billing_status()
  end

  @spec shipment_summary(Accounts.User.t()) :: map()
  def shipment_summary(user) do
    shipments = Shipping.active_shipments_for_user(user)

    %{
      in_transit: Enum.count(shipments, &(&1.status == :in_transit)),
      delivered: Enum.count(shipments, &(&1.status == :delivered)),
      total: length(shipments)
    }
  end

  @spec notification_badge(Accounts.User.t()) :: non_neg_integer()
  def notification_badge(user) do
    user
    |> Notifications.unread_for_user()
    |> length()
  end

  @spec activity_feed(Accounts.User.t(), keyword()) :: [map()]
  def activity_feed(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    [
      Orders.recent_for_user(user, limit: limit),
      Shipping.recent_events_for_user(user, limit: limit),
      Notifications.unread_for_user(user)
    ]
    |> List.flatten()
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  # Private

  defp determine_billing_status([]), do: :no_invoices

  defp determine_billing_status(invoices) do
    if Enum.any?(invoices, &past_due?/1), do: :overdue, else: :current
  end

  defp past_due?(%{due_date: due_date}) do
    Date.compare(due_date, Date.utc_today()) == :lt
  end
end
