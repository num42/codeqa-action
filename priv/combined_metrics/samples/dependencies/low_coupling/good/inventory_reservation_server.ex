defmodule MyApp.Inventory.ReservationServer do
  use GenServer

  alias MyApp.Inventory

  @moduledoc """
  Holds short-lived stock reservations in memory.
  Delegates all persistence and stock math to the Inventory context.
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
    case Inventory.take_stock(sku, quantity) do
      {:ok, hold} ->
        holds = Map.put(state.holds, cart_id, hold)
        {:reply, {:ok, hold}, %{state | holds: holds}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:release, cart_id}, state) do
    {hold, holds} = Map.pop(state.holds, cart_id)
    if hold, do: Inventory.return_stock(hold)
    {:noreply, %{state | holds: holds}}
  end
end
