defmodule ReportGenerator do
  def generate_report(orders, user, opts) do
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    format = Keyword.get(opts, :format, :pdf)

    filtered = Enum.filter(orders, fn order ->
      order.user_id == user.id &&
        (is_nil(start_date) || Date.compare(order.date, start_date) != :lt) &&
        (is_nil(end_date) || Date.compare(order.date, end_date) != :gt)
    end)

    total = Enum.reduce(filtered, 0, fn order, acc ->
      line_total = Enum.reduce(order.items, 0, fn item, item_acc ->
        item_acc + item.price * item.quantity
      end)
      acc + line_total
    end)

    discount = if user.vip do
      total * 0.1
    else
      0
    end

    net_total = total - discount
    tax = net_total * 0.2
    grand_total = net_total + tax

    summary_lines = Enum.map(filtered, fn order ->
      items_text = Enum.map_join(order.items, ", ", fn item ->
        "#{item.name} x#{item.quantity} @ #{item.price}"
      end)
      "Order #{order.id} (#{order.date}): #{items_text}"
    end)

    header = "Report for #{user.name} | #{start_date} - #{end_date}"
    body = Enum.join(summary_lines, "\n")
    footer = "Subtotal: #{total} | Discount: #{discount} | Tax: #{tax} | Total: #{grand_total}"

    content = "#{header}\n\n#{body}\n\n#{footer}"

    case format do
      :pdf -> {:ok, render_pdf(content)}
      :csv -> {:ok, render_csv(filtered, grand_total)}
      :html -> {:ok, "<html><body><pre>#{content}</pre></body></html>"}
      _ -> {:error, :unsupported_format}
    end
  end

  defp render_pdf(content), do: %{type: :pdf, data: content}
  defp render_csv(orders, total), do: %{type: :csv, orders: orders, total: total}
end
