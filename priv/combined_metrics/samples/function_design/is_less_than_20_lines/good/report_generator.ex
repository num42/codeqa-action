defmodule ReportGenerator do
  def generate_report(orders, user, opts) do
    filtered = filter_orders(orders, user, opts)
    totals = calculate_totals(filtered, user)
    content = build_content(filtered, user, totals, opts)
    render(content, filtered, totals, Keyword.get(opts, :format, :pdf))
  end

  defp filter_orders(orders, user, opts) do
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)

    Enum.filter(orders, fn order ->
      order.user_id == user.id &&
        within_date_range?(order.date, start_date, end_date)
    end)
  end

  defp within_date_range?(date, start_date, end_date) do
    (is_nil(start_date) || Date.compare(date, start_date) != :lt) &&
      (is_nil(end_date) || Date.compare(date, end_date) != :gt)
  end

  defp calculate_totals(orders, user) do
    subtotal = Enum.sum(Enum.map(orders, &order_subtotal/1))
    discount = if user.vip, do: subtotal * 0.1, else: 0
    net = subtotal - discount
    %{subtotal: subtotal, discount: discount, net: net, tax: net * 0.2, grand: net + net * 0.2}
  end

  defp order_subtotal(order) do
    Enum.sum(Enum.map(order.items, fn item -> item.price * item.quantity end))
  end

  defp build_content(orders, user, totals, opts) do
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    header = "Report for #{user.name} | #{start_date} - #{end_date}"
    body = Enum.map_join(orders, "\n", &format_order_line/1)
    footer = "Subtotal: #{totals.subtotal} | Discount: #{totals.discount} | Tax: #{totals.tax} | Total: #{totals.grand}"
    "#{header}\n\n#{body}\n\n#{footer}"
  end

  defp format_order_line(order) do
    items_text = Enum.map_join(order.items, ", ", fn item ->
      "#{item.name} x#{item.quantity} @ #{item.price}"
    end)
    "Order #{order.id} (#{order.date}): #{items_text}"
  end

  defp render(content, _orders, _totals, :pdf), do: {:ok, %{type: :pdf, data: content}}
  defp render(_content, orders, totals, :csv), do: {:ok, %{type: :csv, orders: orders, total: totals.grand}}
  defp render(content, _orders, _totals, :html), do: {:ok, "<html><body><pre>#{content}</pre></body></html>"}
  defp render(_content, _orders, _totals, _), do: {:error, :unsupported_format}
end
