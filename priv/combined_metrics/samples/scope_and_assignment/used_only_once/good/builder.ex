defmodule Query.Builder do
  @moduledoc """
  Query/struct builder — GOOD: intermediate results are inlined or piped.
  """

  def build_search_query(filters) do
    from(p in "products")
    |> where(category: ^filters.category)
    |> where([p], p.price <= ^filters.max_price)
    |> where([p], p.stock > 0)
    |> order_by(:inserted_at)
    |> limit(^filters.limit)
  end

  def build_user_struct(attrs) do
    %{
      name: String.trim(attrs.name),
      email: String.downcase(attrs.email),
      role: attrs.role || :guest
    }
  end

  def format_report(data) do
    header = "=== #{String.upcase(data.title)} ==="
    body = data.rows |> Enum.map(&format_row/1) |> Enum.join("\n")
    "#{header}\n#{body}"
  end

  def build_notification(event) do
    %{
      subject: "Event: #{event.name}",
      to: event.user.email,
      body: event.type |> load_template() |> render_template(event)
    }
  end

  def compose_url(base_url, path, query_params) do
    "#{base_url}#{path}?#{URI.encode_query(query_params)}"
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
