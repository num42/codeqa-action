defmodule ShippingQuote do
  def quote(%{weight: w}) when w <= 0, do: {:error, :invalid_weight}

  def quote(%{destination: :domestic} = parcel) do
    {:ok, base_rate(parcel) + weight_surcharge(parcel) + speed_surcharge(parcel)}
  end

  def quote(%{destination: :international} = parcel) do
    {:ok, (base_rate(parcel) + weight_surcharge(parcel)) * 2 + customs_fee(parcel)}
  end

  def quote(_parcel), do: {:error, :unknown_destination}

  defp base_rate(%{destination: :domestic}), do: 5
  defp base_rate(%{destination: :international}), do: 15

  defp weight_surcharge(%{weight: w}) when w > 20, do: 30
  defp weight_surcharge(%{weight: w}) when w > 5, do: 10
  defp weight_surcharge(_parcel), do: 0

  defp speed_surcharge(%{speed: :express}), do: 12
  defp speed_surcharge(%{speed: :priority}), do: 6
  defp speed_surcharge(_parcel), do: 0

  defp customs_fee(%{declared_value: v}) when v > 100, do: 25
  defp customs_fee(_parcel), do: 8
end
