defmodule Pipeline.Processor do
  @moduledoc """
  Data processing pipeline — GOOD: variables declared immediately before use.
  """

  def process_order(order) do
    min_price = 0.01
    max_items = 50

    validated =
      Enum.filter(order.items, fn item ->
        item.quantity > 0 and item.price >= min_price and length(order.items) <= max_items
      end)

    subtotal =
      Enum.reduce(validated, 0, fn item, acc ->
        acc + item.price * item.quantity
      end)

    discount_threshold = 100
    premium_discount = 0.15
    standard_discount = 0.05

    discount =
      if subtotal > discount_threshold do
        subtotal * premium_discount
      else
        subtotal * standard_discount
      end

    discounted = subtotal - discount
    tax_rate = 0.08
    tax = discounted * tax_rate
    total = discounted + tax

    currency = "USD"
    %{total: total, currency: currency, item_count: length(validated)}
  end

  def process_batch(orders) do
    max_batch_size = 200

    if length(orders) > max_batch_size do
      {:batch_error, :too_large}
    else
      results =
        Enum.map(orders, fn order ->
          case process_order(order) do
            %{total: t} when t > 0 -> {:ok, t}
            _ -> {:batch_error, order.id}
          end
        end)

      successes = Enum.count(results, &match?({:ok, _}, &1))
      batch_id = System.unique_integer([:positive])
      started_at = DateTime.utc_now()

      %{
        batch_id: batch_id,
        started_at: started_at,
        total: length(orders),
        successes: successes
      }
    end
  end

  def summarize(results) do
    lines = Enum.map(results, fn {status, val} -> "#{status}: #{val}" end)
    body = Enum.join(lines, "\n")

    label = "Summary"
    separator = String.duplicate("-", 40)

    "#{label}\n#{separator}\n#{body}"
  end
end
