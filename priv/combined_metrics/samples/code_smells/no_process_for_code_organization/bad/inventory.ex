defmodule MyApp.Inventory do
  @moduledoc """
  Inventory calculations. Unnecessarily uses a GenServer to hold a map
  that could simply be passed as function arguments. The GenServer adds
  overhead and serializes all access with no benefit.
  """

  use GenServer

  # Bad: using a GenServer purely to hold a map that needs no
  # concurrency protection or long-lived state.
  def start_link(products) do
    GenServer.start_link(__MODULE__, products, name: __MODULE__)
  end

  @impl true
  def init(products) do
    {:ok, Map.new(products, &{&1.id, &1})}
  end

  # Bad: simple computation wrapped in a GenServer.call — all callers
  # are serialized through a single process for no reason.
  @spec sufficient_stock?(integer(), pos_integer()) :: boolean()
  def sufficient_stock?(product_id, quantity) do
    GenServer.call(__MODULE__, {:sufficient_stock, product_id, quantity})
  end

  @spec compute_reservation([{integer(), pos_integer()}]) :: map()
  def compute_reservation(items) do
    GenServer.call(__MODULE__, {:compute_reservation, items})
  end

  @spec reorder_point(integer()) :: integer()
  def reorder_point(product_id) do
    GenServer.call(__MODULE__, {:reorder_point, product_id})
  end

  @impl true
  def handle_call({:sufficient_stock, product_id, quantity}, _from, products) do
    result =
      case Map.get(products, product_id) do
        nil -> false
        product -> product.stock >= quantity
      end
    {:reply, result, products}
  end

  @impl true
  def handle_call({:compute_reservation, items}, _from, products) do
    result =
      Enum.reduce(items, %{available: [], unavailable: []}, fn {id, qty}, acc ->
        product = Map.get(products, id)
        if product && product.stock >= qty do
          Map.update!(acc, :available, &[{id, qty} | &1])
        else
          Map.update!(acc, :unavailable, &[{id, qty} | &1])
        end
      end)
    {:reply, result, products}
  end

  @impl true
  def handle_call({:reorder_point, product_id}, _from, products) do
    result =
      case Map.get(products, product_id) do
        nil -> 0
        product -> ceil(product.daily_usage * product.lead_time_days * 1.2)
      end
    {:reply, result, products}
  end
end
