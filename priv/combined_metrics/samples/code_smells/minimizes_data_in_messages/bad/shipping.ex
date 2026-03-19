defmodule MyApp.Shipping.LabelWorker do
  @moduledoc """
  Generates shipping labels asynchronously.
  """

  use GenServer

  alias MyApp.Orders.Order
  alias MyApp.Shipping

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Bad: enqueues the entire Order struct in the message.
  # This copies the full struct (including all its associations) into the
  # worker's mailbox, wasting memory and defeating the purpose of async work.
  @spec enqueue(Order.t()) :: :ok
  def enqueue(%Order{} = order) do
    GenServer.cast(__MODULE__, {:generate_label, order})
  end

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  # Bad: entire order struct is in the message payload — large copy
  def handle_cast({:generate_label, %Order{} = order}, state) do
    # The worker already received a (potentially stale) full struct
    Task.start(fn -> Shipping.generate_label(order) end)
    {:noreply, state}
  end
end

defmodule MyApp.Shipping.BatchNotifier do
  @moduledoc """
  Broadcasts shipping updates.
  """

  alias MyApp.Shipping.Shipment

  # Bad: broadcasts the full Shipment struct to all subscribers.
  # If 100 processes subscribe, this full struct is copied 100 times.
  @spec notify_dispatched(Shipment.t()) :: :ok | {:error, term()}
  def notify_dispatched(%Shipment{} = shipment) do
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "shipments",
      # Bad: sending the entire struct with all fields
      {:shipment_dispatched, shipment}
    )
  end

  # Bad: spawning a closure that captures the full struct
  @spec process_async(Shipment.t()) :: :ok
  def process_async(%Shipment{} = shipment) do
    # Bad: the full shipment struct is captured in the closure
    # and copied into the new process's heap
    spawn(fn ->
      Shipping.finalize(shipment)
      Shipping.archive(shipment)
      Shipping.notify_customer(shipment)
    end)

    :ok
  end
end
