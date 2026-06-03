defmodule CartPricing do
  def total(items) when is_list(items) do
    items
    |> Enum.map(&line_total/1)
    |> sum_lines()
  end

  def total(_), do: {:error, "items must be a list"}

  defp sum_lines(lines) do
    case Enum.find(lines, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.sum(lines)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp line_total(%{price: price, qty: qty} = item)
       when is_number(price) and is_integer(qty) and qty > 0 do
    price * qty * (1 - discount(item))
  end

  defp line_total(%{qty: qty}) when qty <= 0, do: {:error, "qty must be positive"}
  defp line_total(_), do: {:error, "invalid line item"}

  defp discount(%{tier: :gold}), do: 0.20
  defp discount(%{tier: :silver}), do: 0.10
  defp discount(_), do: 0.0
end
