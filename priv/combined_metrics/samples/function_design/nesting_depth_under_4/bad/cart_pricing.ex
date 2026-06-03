defmodule CartPricing do
  def total(items) do
    if is_list(items) do
      lines =
        Enum.map(items, fn item ->
          if is_number(item[:price]) do
            if is_integer(item[:qty]) do
              if item[:qty] > 0 do
                discount =
                  case item[:tier] do
                    :gold -> 0.20
                    :silver -> 0.10
                    _ -> 0.0
                  end

                item[:price] * item[:qty] * (1 - discount)
              else
                {:error, "qty must be positive"}
              end
            else
              {:error, "invalid line item"}
            end
          else
            {:error, "invalid line item"}
          end
        end)

      case Enum.find(lines, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.sum(lines)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "items must be a list"}
    end
  end
end
