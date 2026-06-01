class ShoppingCart
  attr_reader :line_items, :customer_id, :coupon_code

  def initialize(customer_id)
    @customer_id = customer_id
    @line_items = []
    @coupon_code = nil
  end

  def add_item(product_id, quantity: 1, unit_price:)
    existing = find_line_item(product_id)

    if existing
      existing.increment_quantity(quantity)
    else
      @line_items << LineItem.new(product_id: product_id, quantity: quantity, unit_price: unit_price)
    end

    self
  end

  def remove_item(product_id)
    @line_items.reject! { |item| item.product_id == product_id }
    self
  end

  def apply_coupon_code(code)
    @coupon_code = code
    self
  end

  def calculate_subtotal
    line_items.sum(&:line_total)
  end

  def calculate_tax(rate:)
    calculate_subtotal * rate
  end

  def total_item_count
    line_items.sum(&:quantity)
  end

  def empty?
    line_items.empty?
  end

  private

  def find_line_item(product_id)
    line_items.find { |item| item.product_id == product_id }
  end
end
