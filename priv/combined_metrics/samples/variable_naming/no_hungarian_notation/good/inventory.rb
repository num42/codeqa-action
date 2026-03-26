# Inventory management without Hungarian notation prefixes.
# GOOD: name, is_active, count, items, age, user, callback, price — no type prefixes.

class InventoryGood
  def add_item(item)
    name = item[:name]
    sku = item[:sku]
    quantity = item[:quantity]
    price = item[:price]
    is_active = item.fetch(:active, true)

    return { ok: false, error: 'Name is required' } if name.nil? || name.strip.empty?

    {
      ok: true,
      data: { id: generate_id, name: name, sku: sku, quantity: quantity, price: price, active: is_active }
    }
  end

  def update_stock(item_id, delta)
    item = fetch_item(item_id)
    new_quantity = item[:quantity] + delta

    return { ok: false, error: 'Insufficient stock' } if new_quantity < 0

    { ok: true, data: item.merge(quantity: new_quantity) }
  end

  def search_items(query, items)
    lower_query = query.downcase

    items.select do |item|
      item[:name].downcase.include?(lower_query) ||
        item[:sku].downcase.include?(lower_query)
    end
  end

  def calculate_value(items)
    items.sum { |item| item[:quantity] * item[:price] }
  end

  def apply_discount(items, discount_rate, filter)
    items
      .select(&filter)
      .map do |item|
        new_price = (item[:price] * (1 - discount_rate)).round(2)
        item.merge(price: new_price)
      end
  end

  def group_by_category(items)
    items.group_by { |item| item[:category] }
  end

  def low_stock_report(items, threshold)
    include_inactive = false

    items
      .select { |item| item[:quantity] <= threshold && (include_inactive || item[:active]) }
      .sort_by { |item| item[:quantity] }
  end

  def import_items(raw_data, transform, validate)
    transformed = raw_data.map(&transform)
    valid = transformed.select(&validate)
    imported = valid.length
    skipped = raw_data.length - imported

    { imported: imported, skipped: skipped, items: valid }
  end

  private

  def fetch_item(id)
    { id: id, name: 'Item', sku: 'SKU', quantity: 10, price: 9.99, active: true, category: 'misc' }
  end

  def generate_id = SecureRandom.hex(8)
end
