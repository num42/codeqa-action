defmodule Logistics.ShippingRules do
  @moduledoc """
  Shipping eligibility checks — GOOD: booleans assigned directly from
  comparison expressions and predicate calls, not derived via conditionals.
  """

  def evaluate(order, zone) do
    is_domestic = order.country == zone.home_country
    is_express = order.service in [:express, :overnight]
    is_oversized = order.weight_kg > zone.weight_limit_kg
    free_shipping = order.subtotal_cents >= zone.free_threshold_cents and is_domestic

    %{
      domestic: is_domestic,
      express: is_express,
      oversized: is_oversized,
      free_shipping: free_shipping
    }
  end

  def customs_required?(parcel) do
    crosses_border = parcel.origin_country != parcel.dest_country
    declarable = parcel.declared_value_cents > 0
    not_exempt = parcel.category not in [:documents, :gift_under_limit]

    crosses_border and declarable and not_exempt
  end

  def delivery_state(shipment, now) do
    delivered = shipment.delivered_at != nil
    in_transit = shipment.dispatched_at != nil and not delivered
    delayed = in_transit and DateTime.diff(now, shipment.expected_at, :hour) > 0

    %{delivered: delivered, in_transit: in_transit, delayed: delayed}
  end
end
