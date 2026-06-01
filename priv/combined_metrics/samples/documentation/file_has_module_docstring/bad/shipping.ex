defmodule MyApp.Shipping do
  alias MyApp.Repo
  alias MyApp.Shipping.Shipment
  alias MyApp.Shipping.TrackingEvent
  alias MyApp.Orders.Order

  @spec create_shipment(Order.t(), map()) :: {:ok, Shipment.t()} | {:error, Ecto.Changeset.t()}
  def create_shipment(%Order{} = order, attrs) do
    %Shipment{}
    |> Shipment.changeset(Map.put(attrs, :order_id, order.id))
    |> Repo.insert()
  end

  @spec get_shipment!(integer()) :: Shipment.t()
  def get_shipment!(id) do
    Repo.get!(Shipment, id)
    |> Repo.preload(:tracking_events)
  end

  @spec update_shipment(Shipment.t(), map()) :: {:ok, Shipment.t()} | {:error, Ecto.Changeset.t()}
  def update_shipment(%Shipment{} = shipment, attrs) do
    shipment
    |> Shipment.changeset(attrs)
    |> Repo.update()
  end

  @spec cancel_shipment(Shipment.t()) :: {:ok, Shipment.t()} | {:error, Ecto.Changeset.t()}
  def cancel_shipment(%Shipment{} = shipment) do
    update_shipment(shipment, %{status: :cancelled})
  end

  @spec add_tracking_event(Shipment.t(), map()) ::
          {:ok, TrackingEvent.t()} | {:error, Ecto.Changeset.t()}
  def add_tracking_event(%Shipment{} = shipment, attrs) do
    %TrackingEvent{}
    |> TrackingEvent.changeset(Map.put(attrs, :shipment_id, shipment.id))
    |> Repo.insert()
  end

  @spec estimated_delivery(Shipment.t()) :: Date.t() | nil
  def estimated_delivery(%Shipment{shipped_at: nil}), do: nil

  def estimated_delivery(%Shipment{shipped_at: shipped_at, service: service}) do
    days = transit_days(service)
    Date.add(DateTime.to_date(shipped_at), days)
  end

  @spec active_shipments_for_user(map()) :: [Shipment.t()]
  def active_shipments_for_user(%{id: user_id}) do
    Repo.all(
      from s in Shipment,
        join: o in Order,
        on: o.id == s.order_id,
        where: o.user_id == ^user_id and s.status == :in_transit
    )
  end

  @spec calculate_shipping_cost(map(), String.t()) :: Decimal.t()
  def calculate_shipping_cost(%{weight_grams: weight}, destination_zone) do
    base = base_rate(destination_zone)
    weight_cost = Decimal.mult(Decimal.new(weight), Decimal.new("0.001"))
    Decimal.add(base, weight_cost)
  end

  defp transit_days(:standard), do: 5
  defp transit_days(:express), do: 2
  defp transit_days(:overnight), do: 1
  defp transit_days(_), do: 7

  defp base_rate("domestic"), do: Decimal.new("4.99")
  defp base_rate("international"), do: Decimal.new("19.99")
  defp base_rate(_), do: Decimal.new("9.99")
end
