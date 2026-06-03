defmodule ShippingQuote do
  def quote(parcel) do
    if parcel.weight <= 0 do
      {:error, :invalid_weight}
    else
      if parcel.destination == :domestic do
        base = 5

        weight =
          cond do
            parcel.weight > 20 -> 30
            parcel.weight > 5 -> 10
            true -> 0
          end

        speed =
          cond do
            parcel.speed == :express -> 12
            parcel.speed == :priority -> 6
            true -> 0
          end

        {:ok, base + weight + speed}
      else
        if parcel.destination == :international do
          base = 15

          weight =
            cond do
              parcel.weight > 20 -> 30
              parcel.weight > 5 -> 10
              true -> 0
            end

          customs = if parcel.declared_value > 100, do: 25, else: 8
          {:ok, (base + weight) * 2 + customs}
        else
          {:error, :unknown_destination}
        end
      end
    end
  end
end
