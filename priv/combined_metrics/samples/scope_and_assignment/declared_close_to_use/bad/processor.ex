defmodule Pipeline.Processor do
  @moduledoc """
  Data processing pipeline — BAD: variables declared far from their use.
  """

  def process_order(order) do
    # All variables declared upfront, used much later
    tax_rate = 0.08
    discount_threshold = 100
    premium_discount = 0.15
    standard_discount = 0.05
    currency = "USD"
    max_items = 50
    min_price = 0.01

    items = order.items

    validated =
      Enum.filter(items, fn item ->
        item.quantity > 0 and item.price >= min_price and length(items) <= max_items
      end)

    subtotal =
      Enum.reduce(validated, 0, fn item, acc ->
        acc + item.price * item.quantity
      end)

    # discount_threshold, premium_discount, standard_discount declared ~15 lines ago
    discount =
      if subtotal > discount_threshold do
        subtotal * premium_discount
      else
        subtotal * standard_discount
      end

    discounted = subtotal - discount

    # tax_rate declared ~20 lines ago
    tax = discounted * tax_rate

    total = discounted + tax

    # currency declared ~22 lines ago
    %{total: total, currency: currency, item_count: length(validated)}
  end

  def process_batch(orders) do
    # Variables declared at top, used at different depths
    batch_id = System.unique_integer([:positive])
    started_at = DateTime.utc_now()
    max_batch_size = 200
    error_tag = :batch_error

    if length(orders) > max_batch_size do
      # error_tag used for the first time ~7 lines after declaration
      {error_tag, :too_large}
    else
      results =
        Enum.map(orders, fn order ->
          case process_order(order) do
            %{total: t} when t > 0 -> {:ok, t}
            # error_tag used again here, many lines from declaration
            _ -> {error_tag, order.id}
          end
        end)

      # started_at and batch_id used ~20 lines after declaration
      successes = Enum.count(results, &match?({:ok, _}, &1))

      %{
        batch_id: batch_id,
        started_at: started_at,
        total: length(orders),
        successes: successes
      }
    end
  end

  def summarize(results) do
    label = "Summary"
    separator = String.duplicate("-", 40)
    format = :detailed

    lines = Enum.map(results, fn {status, val} -> "#{status}: #{val}" end)
    body = Enum.join(lines, "\n")

    # label, separator, format all declared ~8 lines ago
    if format == :detailed do
      "#{label}\n#{separator}\n#{body}"
    else
      "#{label}: #{length(lines)} results"
    end
  end
end
