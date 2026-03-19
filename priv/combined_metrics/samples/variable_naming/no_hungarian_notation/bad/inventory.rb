# Inventory management using Hungarian notation prefixes.
# BAD: str_name, b_active, n_count, arr_items, int_age, obj_user, fn_callback, d_price.

class InventoryBad
  def add_item(obj_item)
    str_name = obj_item[:name]
    str_sku = obj_item[:sku]
    n_quantity = obj_item[:quantity]
    d_price = obj_item[:price]
    b_active = obj_item.fetch(:active, true)

    return { ok: false, error: 'Name is required' } if str_name.nil? || str_name.strip.empty?

    {
      ok: true,
      data: { id: generate_id, name: str_name, sku: str_sku, quantity: n_quantity, price: d_price, active: b_active }
    }
  end

  def update_stock(str_item_id, n_delta)
    obj_item = fetch_item(str_item_id)
    n_new_quantity = obj_item[:quantity] + n_delta

    return { ok: false, error: 'Insufficient stock' } if n_new_quantity < 0

    { ok: true, data: obj_item.merge(quantity: n_new_quantity) }
  end

  def search_items(str_query, arr_items)
    str_lower_query = str_query.downcase

    arr_items.select do |obj_item|
      obj_item[:name].downcase.include?(str_lower_query) ||
        obj_item[:sku].downcase.include?(str_lower_query)
    end
  end

  def calculate_value(arr_items)
    arr_items.sum { |obj_item| obj_item[:quantity] * obj_item[:price] }
  end

  def apply_discount(arr_items, d_discount_rate, fn_filter)
    arr_items
      .select(&fn_filter)
      .map do |obj_item|
        d_new_price = (obj_item[:price] * (1 - d_discount_rate)).round(2)
        obj_item.merge(price: d_new_price)
      end
  end

  def group_by_category(arr_items)
    arr_items.group_by { |obj_item| obj_item[:category] }
  end

  def low_stock_report(arr_items, n_threshold)
    b_include_inactive = false

    arr_items
      .select { |obj_item| obj_item[:quantity] <= n_threshold && (b_include_inactive || obj_item[:active]) }
      .sort_by { |obj_item| obj_item[:quantity] }
  end

  def import_items(arr_raw_data, fn_transform, fn_validate)
    arr_transformed = arr_raw_data.map(&fn_transform)
    arr_valid = arr_transformed.select(&fn_validate)
    n_imported = arr_valid.length
    n_skipped = arr_raw_data.length - n_imported

    { imported: n_imported, skipped: n_skipped, items: arr_valid }
  end

  private

  def fetch_item(str_id)
    { id: str_id, name: 'Item', sku: 'SKU', quantity: 10, price: 9.99, active: true, category: 'misc' }
  end

  def generate_id = SecureRandom.hex(8)
end
