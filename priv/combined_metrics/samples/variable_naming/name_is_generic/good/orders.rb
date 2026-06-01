class OrderProcessor
  def calculate_order_totals(orders)
    processed_orders = orders.reduce([]) do |finalized_orders, order|
      order_subtotal = order[:price] * order[:quantity]
      order_summary = { id: order[:id], total: order_subtotal, status: order[:status] }

      finalized_order = if order_subtotal > 100
        discounted_order = apply_discount(order_summary, 0.1)
        add_tax(discounted_order, 0.2)
      else
        add_tax(order_summary, 0.2)
      end

      finalized_orders + [finalized_order]
    end

    processed_orders
  end

  def apply_discount(order, discount_rate)
    discounted_total = order[:total] * (1 - discount_rate)
    order.merge(total: discounted_total)
  end

  def add_tax(order, tax_rate)
    taxed_total = order[:total] * (1 + tax_rate)
    order.merge(total: taxed_total)
  end

  def filter_by_minimum_total(orders, minimum_total)
    orders.select { |order| order[:total] > minimum_total }
  end

  def summarize_orders(orders)
    rounded_orders = orders.map do |order|
      rounded_total = order[:total].round(2)
      { id: order[:id], total: rounded_total, status: order[:status] }
    end

    grand_total = rounded_orders.reduce(0.0) { |running_total, order| running_total + order[:total] }

    { items: rounded_orders, grand_total: grand_total }
  end

  def group_by_total_threshold(orders, threshold)
    orders.group_by do |order|
      order[:total] > threshold ? :high_value : :low_value
    end
  end

  def validate_orders(orders)
    orders.select do |order|
      has_positive_price = order[:price] > 0
      has_positive_quantity = order[:quantity] > 0
      has_status = !order[:status].nil?
      has_positive_price && has_positive_quantity && has_status
    end
  end

  def enrich_with_customer_data(orders, customer_map)
    orders.map do |order|
      customer_data = customer_map[order[:id]] || {}
      enriched_order = order.merge(customer_data)
      enriched_order
    end
  end

  def format_orders_for_display(orders)
    orders.map do |order|
      formatted_order = {
        id: order[:id],
        total: "$#{format('%.2f', order[:total])}",
        status: order[:status].to_s.upcase
      }
      formatted_order
    end
  end

  def sort_orders_by_field(orders, sort_field)
    orders.sort_by { |order| order[sort_field] }
  end

  def paginate_orders(orders, pagination_opts)
    current_page = pagination_opts[:page] || 1
    orders_per_page = pagination_opts[:per_page] || 10
    offset = (current_page - 1) * orders_per_page
    orders[offset, orders_per_page] || []
  end
end
