defmodule OrderProcessor do
  @tax_rate 0.2
  @discount_rate 0.1
  @discount_threshold 100

  def calculate_order_totals(orders) do
    orders
    |> Enum.map(&process_single_order/1)
  end

  defp process_single_order(order) do
    order
    |> build_order_summary()
    |> maybe_apply_discount()
    |> add_tax(@tax_rate)
  end

  defp build_order_summary(order) do
    %{id: order.id, total: order.price * order.quantity, status: order.status}
  end

  defp maybe_apply_discount(order_summary) do
    if order_summary.total > @discount_threshold do
      apply_discount(order_summary, @discount_rate)
    else
      order_summary
    end
  end

  def apply_discount(order, discount_rate) do
    order
    |> then(fn o -> o.total * (1 - discount_rate) end)
    |> then(fn discounted_total -> Map.put(order, :total, discounted_total) end)
  end

  def add_tax(order, tax_rate) do
    order
    |> then(fn o -> o.total * (1 + tax_rate) end)
    |> then(fn taxed_total -> Map.put(order, :total, taxed_total) end)
  end

  def filter_by_minimum_total(orders, minimum_total) do
    orders
    |> Enum.filter(&(&1.total > minimum_total))
  end

  def summarize_orders(orders) do
    rounded_items =
      orders
      |> Enum.map(&round_order_total/1)

    grand_total =
      rounded_items
      |> Enum.reduce(0.0, fn item, acc -> acc + item.total end)

    %{items: rounded_items, grand_total: grand_total}
  end

  defp round_order_total(order) do
    order
    |> then(fn o -> Float.round(o.total, 2) end)
    |> then(fn rounded_total -> %{id: order.id, total: rounded_total, status: order.status} end)
  end

  def group_by_total_threshold(orders, threshold) do
    orders
    |> Enum.group_by(&total_threshold_key(&1, threshold))
  end

  defp total_threshold_key(order, threshold), do: if(order.total > threshold, do: :high_value, else: :low_value)

  def validate_orders(orders) do
    orders
    |> Enum.filter(&order_valid?/1)
  end

  defp order_valid?(order) do
    order.price > 0 and order.quantity > 0 and order.status != nil
  end

  def enrich_with_customer_data(orders, customer_map) do
    orders
    |> Enum.map(&merge_customer_data(&1, customer_map))
  end

  defp merge_customer_data(order, customer_map) do
    order
    |> then(fn o -> Map.get(customer_map, o.id, %{}) end)
    |> then(fn customer_data -> Map.merge(order, customer_data) end)
  end

  def format_orders_for_display(orders) do
    orders
    |> Enum.map(&format_single_order/1)
  end

  defp format_single_order(order) do
    total_display =
      order.total
      |> Kernel./(1)
      |> :erlang.float_to_binary(decimals: 2)
      |> then(&"$#{&1}")

    status_display = order.status |> to_string() |> String.upcase()

    %{id: order.id, total: total_display, status: status_display}
  end

  def sort_orders_by_field(orders, sort_field) do
    orders
    |> Enum.sort_by(& &1[sort_field])
  end

  def paginate_orders(orders, pagination_opts) do
    page = pagination_opts[:page] || 1
    per_page = pagination_opts[:per_page] || 10
    offset = (page - 1) * per_page

    orders
    |> Enum.slice(offset, per_page)
  end
end
