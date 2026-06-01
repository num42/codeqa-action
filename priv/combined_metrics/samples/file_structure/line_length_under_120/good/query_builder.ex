defmodule QueryBuilder do
  @moduledoc """
  Builds Ecto queries for filtering and sorting records.
  """

  import Ecto.Query

  def build_user_query(filters) do
    roles = Map.get(filters, :roles, ["admin", "member", "viewer"])
    since = Map.get(filters, :since, ~D[2020-01-01])

    from u in "users",
      where: u.active == true,
      where: u.role in ^roles,
      where: u.inserted_at >= ^since
  end

  def build_order_query(user_id, status, date_from, date_to, include_archived) do
    from o in "orders",
      where: o.user_id == ^user_id,
      where: o.status == ^status,
      where: o.inserted_at >= ^date_from,
      where: o.inserted_at <= ^date_to,
      where: ^include_archived or o.archived == false,
      order_by: [desc: o.inserted_at]
  end

  def build_product_query(filters) do
    min_price = Map.get(filters, :min_price, 0)
    max_price = Map.get(filters, :max_price, 999_999)
    categories = Map.get(filters, :categories, [])
    in_stock = Map.get(filters, :in_stock, true)

    from p in "products",
      where: p.price >= ^min_price,
      where: p.price <= ^max_price,
      where: p.category in ^categories,
      where: p.in_stock == ^in_stock,
      select: %{id: p.id, name: p.name, price: p.price, category: p.category}
  end

  def paginate(query, page, per_page) do
    offset = (page - 1) * per_page

    from q in query,
      limit: ^per_page,
      offset: ^offset
  end

  def apply_sort(query, "name_asc"), do: from(q in query, order_by: [asc: q.name])
  def apply_sort(query, "name_desc"), do: from(q in query, order_by: [desc: q.name])
  def apply_sort(query, "created_asc"), do: from(q in query, order_by: [asc: q.inserted_at])
  def apply_sort(query, "created_desc"), do: from(q in query, order_by: [desc: q.inserted_at])
  def apply_sort(query, _), do: query

  def with_preloads(query, preloads) when is_list(preloads) do
    Enum.reduce(preloads, query, fn preload, acc ->
      from q in acc, preload: ^[preload]
    end)
  end

  def build_report_query(tenant_id, report_type, date_start, date_end) do
    from r in "report_entries",
      where: r.tenant_id == ^tenant_id,
      where: r.type == ^report_type,
      where: r.date >= ^date_start,
      where: r.date <= ^date_end
  end

  def build_search_query(search_term, fields, opts) do
    pattern = "%#{String.replace(search_term, "%", "\\%")}%"
    schema = Map.get(opts, :schema, "records")
    limit = Map.get(opts, :limit, 50)
    offset = Map.get(opts, :offset, 0)

    conditions = Enum.map(fields, fn field ->
      dynamic([q], ilike(field(q, ^field), ^pattern))
    end)

    combined = Enum.reduce(conditions, fn cond, acc ->
      dynamic(^acc or ^cond)
    end)

    from q in schema,
      where: ^combined,
      limit: ^limit,
      offset: ^offset
  end
end
