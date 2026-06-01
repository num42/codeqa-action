defmodule MyApp.Dashboard do
  alias MyApp.Accounts.User
  alias MyApp.Accounts.UserToken
  alias MyApp.Accounts.UserProfile
  alias MyApp.Orders.Order
  alias MyApp.Orders.OrderItem
  alias MyApp.Orders.OrderStatus
  alias MyApp.Billing.Invoice
  alias MyApp.Billing.Payment
  alias MyApp.Billing.PaymentMethod
  alias MyApp.Shipping.Shipment
  alias MyApp.Shipping.TrackingEvent
  alias MyApp.Notifications.Notification
  alias MyApp.Notifications.EmailTemplate
  alias MyApp.Analytics.Event, as: AnalyticsEvent
  alias MyApp.Analytics.Report
  alias MyApp.Repo

  @moduledoc """
  Dashboard aggregation module that compiles user-facing metrics
  and summaries from all subdomains.
  """

  @spec summary(User.t()) :: map()
  def summary(%User{} = user) do
    %{
      orders: recent_orders(user),
      invoices: open_invoices(user),
      shipments: active_shipments(user),
      notifications: unread_notifications(user)
    }
  end

  @spec recent_orders(User.t()) :: [Order.t()]
  def recent_orders(%User{id: user_id}) do
    Repo.all(
      from o in Order,
        where: o.user_id == ^user_id,
        order_by: [desc: o.inserted_at],
        limit: 5,
        preload: [:items]
    )
  end

  @spec open_invoices(User.t()) :: [Invoice.t()]
  def open_invoices(%User{id: user_id}) do
    Repo.all(
      from i in Invoice,
        where: i.user_id == ^user_id and i.status == :open
    )
  end

  @spec active_shipments(User.t()) :: [Shipment.t()]
  def active_shipments(%User{id: user_id}) do
    Repo.all(
      from s in Shipment,
        where: s.user_id == ^user_id and s.status == :in_transit,
        preload: [:tracking_events]
    )
  end

  @spec unread_notifications(User.t()) :: [Notification.t()]
  def unread_notifications(%User{id: user_id}) do
    Repo.all(
      from n in Notification,
        where: n.user_id == ^user_id and n.read == false,
        order_by: [desc: n.inserted_at]
    )
  end

  @spec analytics_report(User.t(), Date.t(), Date.t()) :: Report.t()
  def analytics_report(%User{id: user_id}, from, to) do
    events = Repo.all(
      from e in AnalyticsEvent,
        where: e.user_id == ^user_id and e.date >= ^from and e.date <= ^to
    )

    %Report{user_id: user_id, events: events}
  end
end
