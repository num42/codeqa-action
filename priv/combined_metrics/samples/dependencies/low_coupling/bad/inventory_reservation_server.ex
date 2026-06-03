defmodule MyApp.Inventory.ReservationServer do
  use GenServer

  import Ecto.Query

  alias MyApp.Repo
  alias MyApp.Inventory.StockItem
  alias MyApp.Inventory.StockLedger
  alias MyApp.Catalog.Product
  alias MyApp.Warehouse.Location
  alias MyApp.Notifications.Mailer

  @moduledoc """
  Holds short-lived stock reservations in memory.
  """

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def reserve(sku, quantity, cart_id) do
    GenServer.call(__MODULE__, {:reserve, sku, quantity, cart_id})
  end

  def release(cart_id) do
    GenServer.cast(__MODULE__, {:release, cart_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{holds: %{}}}
  end

  @impl true
  def handle_call({:reserve, sku, quantity, cart_id}, _from, state) do
    product = Repo.get_by!(Product, sku: sku)
    item = Repo.one(from(s in StockItem, where: s.product_id == ^product.id))

    if item.available >= quantity do
      changeset = StockItem.changeset(item, %{available: item.available - quantity})
      {:ok, updated} = Repo.update(changeset)

      location = Repo.get_by!(Location, default: true)

      hold =
        Repo.insert!(%StockLedger{
          stock_item_id: updated.id,
          location_id: location.id,
          delta: -quantity,
          cart_id: cart_id
        })

      {:reply, {:ok, hold}, %{state | holds: Map.put(state.holds, cart_id, hold)}}
    else
      Mailer.send_low_stock_alert(product.sku, item.available)
      {:reply, {:error, :insufficient_stock}, state}
    end
  end

  @impl true
  def handle_cast({:release, cart_id}, state) do
    {hold, holds} = Map.pop(state.holds, cart_id)

    if hold do
      item = Repo.get!(StockItem, hold.stock_item_id)
      Repo.update!(StockItem.changeset(item, %{available: item.available - hold.delta}))
      Repo.delete!(hold)
    end

    {:noreply, %{state | holds: holds}}
  end
end
