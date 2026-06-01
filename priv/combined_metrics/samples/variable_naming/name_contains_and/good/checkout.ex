defmodule Checkout.Good do
  @moduledoc """
  Checkout and payment processing with separate, focused variable names.
  GOOD: each variable holds one concept; compound data uses structs or tuples.
  """

  @spec process_order(map()) :: {:ok, map()} | {:error, String.t()}
  def process_order(order) do
    user = fetch_user(order.user_id)
    address = fetch_address(order.user_id)
    subtotal = calculate_subtotal(order.items)
    tax = calculate_tax(subtotal)
    shipping = calculate_shipping(address, order.items)

    total = subtotal + tax + shipping

    {:ok, %{user: user, address: address, total: total}}
  end

  @spec apply_discounts(map(), list()) :: map()
  def apply_discounts(cart, coupons) do
    price = cart.total
    discount = compute_discount(cart, coupons)

    %{
      original: price,
      savings: discount,
      final: price - discount
    }
  end

  @spec build_receipt(map()) :: map()
  def build_receipt(order) do
    name = fetch_customer_name(order.user_id)
    email = fetch_customer_email(order.user_id)
    line_items = group_line_items(order.line_items)
    issued_at = DateTime.utc_now()

    %{customer: name, contact: email, lines: line_items, issued_at: issued_at}
  end

  @spec validate_payment(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_payment(payment) do
    card = extract_card(payment)
    billing = extract_billing(payment)

    if valid_card?(card) && valid_billing?(billing) do
      {:ok, %{card: card, billing: billing}}
    else
      {:error, "Invalid card or billing details"}
    end
  end

  @spec split_order(map(), list()) :: list(map())
  def split_order(order, vendor_ids) do
    Enum.map(vendor_ids, fn vendor_id ->
      items = filter_items_by_vendor(order, vendor_id)
      subtotal = sum_items(items)
      %{vendor_id: vendor_id, items: items, subtotal: subtotal}
    end)
  end

  defp fetch_user(user_id), do: %{id: user_id}
  defp fetch_address(_user_id), do: %{}
  defp calculate_subtotal(items), do: length(items) * 10
  defp calculate_tax(subtotal), do: subtotal * 0.1
  defp calculate_shipping(_address, _items), do: 5
  defp compute_discount(_cart, _coupons), do: 0
  defp fetch_customer_name(_id), do: "Alice"
  defp fetch_customer_email(_id), do: "alice@example.com"
  defp group_line_items(items), do: items
  defp extract_card(payment), do: Map.get(payment, :card)
  defp extract_billing(payment), do: Map.get(payment, :billing)
  defp valid_card?(_), do: true
  defp valid_billing?(_), do: true
  defp filter_items_by_vendor(order, _vendor_id), do: order.line_items
  defp sum_items(items), do: length(items) * 10
end
