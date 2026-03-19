defmodule MyAppWeb.OrderController do
  use MyAppWeb, :controller

  alias MyApp.Repo
  alias MyApp.Orders.Order
  alias MyApp.Orders.OrderItem
  alias MyApp.Accounts.User
  alias MyApp.Billing.Invoice
  alias MyApp.Notifications.Mailer
  alias MyApp.Shipping.ShipmentService

  @moduledoc """
  Controller for order lifecycle management.
  """

  def index(conn, _params) do
    user_id = conn.assigns.current_user.id

    orders =
      Repo.all(
        from o in Order,
          where: o.user_id == ^user_id,
          preload: [:items, :invoice]
      )

    render(conn, :index, orders: orders)
  end

  def show(conn, %{"id" => id}) do
    order = Repo.get!(Order, id) |> Repo.preload([:items, :invoice, :user])
    render(conn, :show, order: order)
  end

  def create(conn, %{"order" => params}) do
    user = Repo.get!(User, conn.assigns.current_user.id)

    changeset = Order.changeset(%Order{}, Map.put(params, "user_id", user.id))

    case Repo.insert(changeset) do
      {:ok, order} ->
        items = Map.get(params, "items", [])

        Enum.each(items, fn item_params ->
          %OrderItem{}
          |> OrderItem.changeset(Map.put(item_params, "order_id", order.id))
          |> Repo.insert!()
        end)

        invoice = Repo.insert!(%Invoice{order_id: order.id, user_id: user.id, status: :open})

        total = Enum.reduce(items, 0, fn i, acc -> acc + i["price"] * i["quantity"] end)
        Repo.update!(Invoice.changeset(invoice, %{total: total}))

        ShipmentService.create_shipment_for_order(order)

        Mailer.send_order_confirmation(user.email, order)

        conn
        |> put_status(:created)
        |> render(:show, order: order)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end

  def cancel(conn, %{"id" => id}) do
    order = Repo.get!(Order, id)

    case Repo.update(Order.changeset(order, %{status: :cancelled})) do
      {:ok, order} ->
        invoice = Repo.get_by!(Invoice, order_id: order.id)
        Repo.update!(Invoice.changeset(invoice, %{status: :voided}))

        shipment = ShipmentService.find_shipment(order.id)
        if shipment, do: ShipmentService.cancel_shipment(shipment)

        user = Repo.get!(User, order.user_id)
        Mailer.send_cancellation_notice(user.email, order)

        render(conn, :show, order: order)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end
end
