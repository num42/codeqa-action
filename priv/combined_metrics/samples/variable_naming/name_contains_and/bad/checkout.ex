defmodule Checkout.Bad do
  @moduledoc """
  Checkout and payment processing with compound variable names using 'and'.
  BAD: variables combine two concepts with 'and' instead of being split.
  """

  @spec process_order(map()) :: {:ok, map()} | {:error, String.t()}
  def process_order(order) do
    user_and_address = fetch_user_and_address(order.user_id)
    price_and_tax = calculate_price_and_tax(order.items)
    shipping_and_handling = calculate_shipping_and_handling(user_and_address, order.items)

    total = price_and_tax.subtotal + price_and_tax.tax + shipping_and_handling

    {:ok, %{
      user: user_and_address.user,
      address: user_and_address.address,
      total: total
    }}
  end

  @spec apply_discounts(map(), list()) :: map()
  def apply_discounts(cart, coupons) do
    price_and_discount = compute_price_and_discount(cart, coupons)

    %{
      original: price_and_discount.price,
      savings: price_and_discount.discount,
      final: price_and_discount.price - price_and_discount.discount
    }
  end

  @spec build_receipt(map()) :: map()
  def build_receipt(order) do
    name_and_email = get_name_and_email(order.user_id)
    items_and_quantities = group_items_and_quantities(order.line_items)
    date_and_time = get_date_and_time()

    %{
      customer: name_and_email.name,
      contact: name_and_email.email,
      lines: items_and_quantities,
      issued_at: date_and_time
    }
  end

  @spec validate_payment(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_payment(payment) do
    card_and_billing = extract_card_and_billing(payment)

    if valid_card_and_billing?(card_and_billing) do
      {:ok, card_and_billing}
    else
      {:error, "Invalid card or billing details"}
    end
  end

  @spec split_order(map(), list()) :: list(map())
  def split_order(order, vendor_ids) do
    Enum.map(vendor_ids, fn vendor_id ->
      items_and_totals = filter_items_and_totals(order, vendor_id)
      %{vendor_id: vendor_id, items: items_and_totals.items, subtotal: items_and_totals.total}
    end)
  end

  defp fetch_user_and_address(user_id), do: %{user: %{id: user_id}, address: %{}}
  defp calculate_price_and_tax(items), do: %{subtotal: length(items) * 10, tax: length(items) * 1}
  defp calculate_shipping_and_handling(_user_and_address, _items), do: 5
  defp compute_price_and_discount(cart, _coupons), do: %{price: cart.total, discount: 0}
  defp get_name_and_email(_id), do: %{name: "Alice", email: "alice@example.com"}
  defp group_items_and_quantities(items), do: items
  defp get_date_and_time, do: DateTime.utc_now()
  defp extract_card_and_billing(payment), do: payment
  defp valid_card_and_billing?(_), do: true
  defp filter_items_and_totals(order, _vendor_id), do: %{items: order.line_items, total: 0}
end
