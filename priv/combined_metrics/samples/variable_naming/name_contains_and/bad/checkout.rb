# Checkout and payment processing with compound variable names using 'and'.
# BAD: variables combine two concepts with 'and' instead of being split.

class CheckoutBad
  def process_order(order)
    user_and_address = fetch_user_and_address(order[:user_id])
    price_and_tax = calculate_price_and_tax(order[:items])
    shipping_and_handling = calculate_shipping_and_handling(user_and_address, order[:items])

    total = price_and_tax[:subtotal] + price_and_tax[:tax] + shipping_and_handling

    {
      user: user_and_address[:user],
      address: user_and_address[:address],
      total: total
    }
  end

  def apply_discounts(cart, coupons)
    price_and_discount = compute_price_and_discount(cart, coupons)

    {
      original: price_and_discount[:price],
      savings: price_and_discount[:discount],
      final: price_and_discount[:price] - price_and_discount[:discount]
    }
  end

  def build_receipt(order)
    name_and_email = get_name_and_email(order[:user_id])
    items_and_quantities = group_items_and_quantities(order[:line_items])
    date_and_time = Time.now

    {
      customer: name_and_email[:name],
      contact: name_and_email[:email],
      lines: items_and_quantities,
      issued_at: date_and_time
    }
  end

  def validate_payment(payment)
    card_and_billing = extract_card_and_billing(payment)

    raise 'Invalid card or billing details' unless valid_card_and_billing?(card_and_billing)

    card_and_billing
  end

  def split_order(order, vendor_ids)
    vendor_ids.map do |vendor_id|
      items_and_totals = filter_items_and_totals(order, vendor_id)
      { vendor_id: vendor_id, items: items_and_totals[:items], subtotal: items_and_totals[:total] }
    end
  end

  def summarize_cart(cart)
    count_and_weight = compute_count_and_weight(cart[:items])
    tax_and_fees = compute_tax_and_fees(cart[:subtotal], cart[:region])

    {
      item_count: count_and_weight[:count],
      total_weight: count_and_weight[:weight],
      tax: tax_and_fees[:tax],
      fees: tax_and_fees[:fees],
      grand_total: cart[:subtotal] + tax_and_fees[:tax] + tax_and_fees[:fees]
    }
  end

  private

  def fetch_user_and_address(user_id) = { user: { id: user_id }, address: {} }
  def calculate_price_and_tax(items) = { subtotal: items.length * 10, tax: items.length * 1 }
  def calculate_shipping_and_handling(_u, _i) = 5
  def compute_price_and_discount(cart, _coupons) = { price: cart[:total], discount: 0 }
  def get_name_and_email(_id) = { name: 'Alice', email: 'alice@example.com' }
  def group_items_and_quantities(items) = items
  def extract_card_and_billing(payment) = payment
  def valid_card_and_billing?(_) = true
  def filter_items_and_totals(order, _vid) = { items: order[:line_items], total: 0 }
  def compute_count_and_weight(items) = { count: items.length, weight: 0 }
  def compute_tax_and_fees(subtotal, _r) = { tax: subtotal * 0.1, fees: 2 }
end
