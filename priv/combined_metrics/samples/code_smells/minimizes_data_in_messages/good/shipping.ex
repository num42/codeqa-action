defmodule MyApp.Shipping.LabelWorker do
  @moduledoc """
  Generates shipping labels asynchronously. Sends only the order ID
  in the message — the worker re-fetches the data it needs from the
  database, avoiding large struct serialisation over process boundaries.
  """

  use GenServer

  alias MyApp.Orders
  alias MyApp.Shipping

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enqueues label generation for the given order ID.
  Sends only the integer ID — not the full order struct.
  """
  @spec enqueue(integer()) :: :ok
  def enqueue(order_id) when is_integer(order_id) do
    GenServer.cast(__MODULE__, {:generate_label, order_id})
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  # Good: message carries only the order_id.
  # The handler fetches the full record inside the worker process.
  def handle_cast({:generate_label, order_id}, state) do
    Task.start(fn -> do_generate(order_id) end)
    {:noreply, state}
  end

  defp do_generate(order_id) do
    # Re-fetch only the fields needed for label generation
    order = Orders.get_order!(order_id)
    Shipping.generate_label(order)
  end
end

defmodule MyApp.Shipping.BatchNotifier do
  @moduledoc """
  Broadcasts shipping updates. Sends only the shipment ID in PubSub
  messages; subscribers fetch full details on demand.
  """

  @doc """
  Publishes a shipment-dispatched event with only the shipment ID.
  """
  @spec notify_dispatched(integer()) :: :ok | {:error, term()}
  def notify_dispatched(shipment_id) when is_integer(shipment_id) do
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "shipments",
      {:shipment_dispatched, shipment_id}
    )
  end
end
