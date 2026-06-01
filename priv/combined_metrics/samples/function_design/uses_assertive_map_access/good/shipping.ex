defmodule MyApp.Shipping do
  @moduledoc """
  Shipping label generation and address validation.
  Uses dot-access (`map.key`) for required fields and
  bracket-access (`map[:key]`) for optional fields.
  """

  alias MyApp.Shipping.{Address, Label, Shipment}

  @doc """
  Builds a shipping label from a shipment. Required fields are
  accessed with dot notation; optional fields use bracket notation.
  """
  @spec build_label(Shipment.t()) :: Label.t()
  def build_label(%Shipment{} = shipment) do
    # Required fields: dot access — crash immediately if missing
    order_id = shipment.order_id
    recipient = shipment.recipient
    carrier = shipment.carrier

    # Optional field: bracket access — may be nil
    reference = shipment[:reference_number]
    instructions = shipment[:delivery_instructions]

    %Label{
      order_id: order_id,
      to_name: recipient.name,
      to_address: format_address(recipient.address),
      carrier: carrier,
      reference: reference,
      instructions: instructions
    }
  end

  @doc """
  Validates a shipping address. Required fields accessed with dot notation.
  """
  @spec validate_address(Address.t()) :: :ok | {:error, [String.t()]}
  def validate_address(%Address{} = address) do
    # Dot access for required fields
    errors =
      []
      |> check_present(address.street, "street is required")
      |> check_present(address.city, "city is required")
      |> check_present(address.country, "country is required")

    # Bracket access for optional fields
    _postal = address[:postal_code]
    _state = address[:state]

    case errors do
      [] -> :ok
      errs -> {:error, errs}
    end
  end

  @doc """
  Calculates the shipping cost for a shipment.
  """
  @spec calculate_cost(Shipment.t()) :: float()
  def calculate_cost(%Shipment{} = shipment) do
    # Required — dot access
    base_rate = shipment.carrier_rate
    weight = shipment.weight_grams

    # Optional — bracket access
    insurance = shipment[:insurance_value] || 0
    discount = shipment[:discount_rate] || 0.0

    (base_rate + weight * 0.01 + insurance * 0.001) * (1.0 - discount)
  end

  defp check_present(errors, nil, msg), do: [msg | errors]
  defp check_present(errors, "", msg), do: [msg | errors]
  defp check_present(errors, _, _), do: errors

  defp format_address(%Address{} = addr) do
    "#{addr.street}, #{addr.city}, #{addr.country}"
  end
end
