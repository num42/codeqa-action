# Checkout and payment processing with separate, focused variable names.
# GOOD: each variable holds one concept; compound data uses plain hashes.

class CheckoutGood
  def process_order(order)
    user = fetch_user(order[:user_id])
    address = fetch_address(order[:user_id])
    subtotal = calculate_subtotal(order[:items])
    tax = calculate_tax(subtotal)
    shipping = calculate_shipping(address, order[:items])

    total = subtotal + tax + shipping

    { user: user, address: address, total: total }
  end

  def apply_discounts(cart, coupons)
    price = cart[:total]
    discount = compute_discount(cart, coupons)

    {
      original: price,
      savings: discount,
      final: price - discount
    }
  end

  def build_receipt(order)
    name = fetch_customer_name(order[:user_id])
    email = fetch_customer_email(order[:user_id])
    line_items = group_line_items(order[:line_items])
    issued_at = Time.now

    { customer: name, contact: email, lines: line_items, issued_at: issued_at }
  end

  def validate_payment(payment)
    card = extract_card(payment)
    billing = extract_billing(payment)

    raise 'Invalid card or billing details' unless valid_card?(card) && valid_billing?(billing)

    { card: card, billing: billing }
  end

  def split_order(order, vendor_ids)
    vendor_ids.map do |vendor_id|
      items = filter_items_by_vendor(order, vendor_id)
      subtotal = sum_items(items)
      { vendor_id: vendor_id, items: items, subtotal: subtotal }
    end
  end

  def summarize_cart(cart)
    count = cart[:items].length
    weight = compute_weight(cart[:items])
    tax = compute_tax(cart[:subtotal], cart[:region])
    fees = compute_fees(cart[:subtotal], cart[:region])

    {
      item_count: count,
      total_weight: weight,
      tax: tax,
      fees: fees,
      grand_total: cart[:subtotal] + tax + fees
    }
  end

  private

  def fetch_user(user_id) = { id: user_id }
  def fetch_address(_user_id) = {}
  def calculate_subtotal(items) = items.length * 10
  def calculate_tax(subtotal) = subtotal * 0.1
  def calculate_shipping(_address, _items) = 5
  def compute_discount(_cart, _coupons) = 0
  def fetch_customer_name(_id) = 'Alice'
  def fetch_customer_email(_id) = 'alice@example.com'
  def group_line_items(items) = items
  def extract_card(payment) = payment[:card]
  def extract_billing(payment) = payment[:billing]
  def valid_card?(_) = true
  def valid_billing?(_) = true
  def filter_items_by_vendor(order, _vid) = order[:line_items]
  def sum_items(items) = items.length * 10
  def compute_weight(_items) = 0
  def compute_tax(subtotal, _region) = subtotal * 0.1
  def compute_fees(_subtotal, _region) = 2
end
