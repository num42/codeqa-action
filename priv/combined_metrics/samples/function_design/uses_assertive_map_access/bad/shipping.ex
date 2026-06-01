defmodule MyApp.Shipping do
  @moduledoc """
  Shipping label generation and address validation.
  """

  alias MyApp.Shipping.{Address, Label, Shipment}

  # Bad: bracket access used for required fields — silently returns nil
  # instead of crashing, making bugs harder to detect
  @spec build_label(Shipment.t()) :: Label.t()
  def build_label(%Shipment{} = shipment) do
    # Bad: these are required — should use dot access
    order_id = shipment[:order_id]
    recipient = shipment[:recipient]
    carrier = shipment[:carrier]

    # Bad: required nested fields also use bracket access
    to_name = recipient[:name]
    raw_address = recipient[:address]

    %Label{
      order_id: order_id,
      to_name: to_name,
      to_address: format_address(raw_address),
      carrier: carrier
    }
  end

  # Bad: dot access on a plain map for optional fields that may not exist,
  # causing a KeyError for optional data
  @spec validate_address(map()) :: :ok | {:error, [String.t()]}
  def validate_address(address) do
    # Bad: dot access on a plain map will raise if key is missing
    street = address.street
    city = address.city
    country = address.country
    # Also bad for optional fields: should use bracket access, not dot
    postal = address.postal_code
    state = address.state

    errors =
      []
      |> check_present(street, "street is required")
      |> check_present(city, "city is required")
      |> check_present(country, "country is required")

    case errors do
      [] -> :ok
      errs -> {:error, errs}
    end
  end

  # Bad: all fields accessed with bracket notation even required ones
  @spec calculate_cost(Shipment.t()) :: float()
  def calculate_cost(shipment) do
    base_rate = shipment[:carrier_rate] || 0
    weight = shipment[:weight_grams] || 0
    insurance = shipment[:insurance_value] || 0
    discount = shipment[:discount_rate] || 0.0

    (base_rate + weight * 0.01 + insurance * 0.001) * (1.0 - discount)
  end

  defp check_present(errors, nil, msg), do: [msg | errors]
  defp check_present(errors, "", msg), do: [msg | errors]
  defp check_present(errors, _, _), do: errors

  defp format_address(addr) when is_map(addr) do
    "#{addr[:street]}, #{addr[:city]}, #{addr[:country]}"
  end
end
