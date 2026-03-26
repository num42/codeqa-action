defmodule Query.Builder do
  @moduledoc """
  Query/struct builder — BAD: intermediate variables used exactly once and could be inlined.
  """

  def build_search_query(filters) do
    base = from(p in "products")
    with_category = where(base, category: ^filters.category)
    with_price = where(with_category, [p], p.price <= ^filters.max_price)
    with_stock = where(with_price, [p], p.stock > 0)
    ordered = order_by(with_stock, :inserted_at)
    limited = limit(ordered, ^filters.limit)
    limited
  end

  def build_user_struct(attrs) do
    name = String.trim(attrs.name)
    email = String.downcase(attrs.email)
    role = attrs.role || :guest
    struct = %{name: name, email: email, role: role}
    struct
  end

  def format_report(data) do
    title = String.upcase(data.title)
    header = "=== #{title} ==="
    rows = Enum.map(data.rows, &format_row/1)
    body = Enum.join(rows, "\n")
    report = "#{header}\n#{body}"
    report
  end

  def build_notification(event) do
    subject = "Event: #{event.name}"
    recipient = event.user.email
    template = load_template(event.type)
    rendered = render_template(template, event)
    notification = %{subject: subject, to: recipient, body: rendered}
    notification
  end

  def compose_url(base_url, path, query_params) do
    encoded = URI.encode_query(query_params)
    full_path = "#{path}?#{encoded}"
    url = "#{base_url}#{full_path}"
    url
  end

  defp format_row(row), do: "#{row.label}: #{row.value}"
  defp load_template(type), do: "template_#{type}"
  defp render_template(t, _e), do: t
  defp from(q), do: q
  defp where(q, _), do: q
  defp where(q, _, _), do: q
  defp order_by(q, _), do: q
  defp limit(q, _), do: q
end
