defmodule MyAppWeb.OrderController do
  use MyAppWeb, :controller

  alias MyApp.Orders

  @moduledoc """
  Controller for order lifecycle management.
  Delegates all business logic to the Orders context.
  """

  action_fallback MyAppWeb.FallbackController

  def index(conn, _params) do
    orders = Orders.list_orders_for_user(conn.assigns.current_user)
    render(conn, :index, orders: orders)
  end

  def show(conn, %{"id" => id}) do
    with {:ok, order} <- Orders.get_order(id, conn.assigns.current_user) do
      render(conn, :show, order: order)
    end
  end

  def create(conn, %{"order" => params}) do
    with {:ok, order} <- Orders.place_order(conn.assigns.current_user, params) do
      conn
      |> put_status(:created)
      |> render(:show, order: order)
    end
  end

  def cancel(conn, %{"id" => id}) do
    with {:ok, order} <- Orders.get_order(id, conn.assigns.current_user),
         {:ok, cancelled} <- Orders.cancel_order(order) do
      render(conn, :show, order: cancelled)
    end
  end

  def update(conn, %{"id" => id, "order" => params}) do
    with {:ok, order} <- Orders.get_order(id, conn.assigns.current_user),
         {:ok, updated} <- Orders.update_order(order, params) do
      render(conn, :show, order: updated)
    end
  end

  def history(conn, params) do
    page = Map.get(params, "page", 1)
    per_page = Map.get(params, "per_page", 20)

    orders = Orders.order_history_for_user(conn.assigns.current_user,
      page: page,
      per_page: per_page
    )

    render(conn, :index, orders: orders)
  end
end
