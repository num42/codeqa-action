defmodule QueryBuilder do
  @moduledoc """
  Builds Ecto queries for filtering and sorting records.
  """

  import Ecto.Query

  def build_user_query(filters) do
    from(u in "users", where: u.active == true and u.role in ^Map.get(filters, :roles, ["admin", "member", "viewer", "guest"]) and u.inserted_at >= ^Map.get(filters, :since, ~D[2020-01-01]))
  end

  def build_order_query(user_id, status, date_from, date_to, include_archived) do
    from(o in "orders", where: o.user_id == ^user_id and o.status == ^status and o.inserted_at >= ^date_from and o.inserted_at <= ^date_to and (^include_archived or o.archived == false), order_by: [desc: o.inserted_at])
  end

  def build_product_query(filters) do
    from(p in "products", where: p.price >= ^Map.get(filters, :min_price, 0) and p.price <= ^Map.get(filters, :max_price, 999_999) and p.category in ^Map.get(filters, :categories, []) and p.in_stock == ^Map.get(filters, :in_stock, true), select: %{id: p.id, name: p.name, price: p.price, category: p.category, description: p.description})
  end

  def paginate(query, page, per_page) do
    offset = (page - 1) * per_page
    from(q in query, limit: ^per_page, offset: ^offset)
  end

  def apply_sort(query, "name_asc"), do: from(q in query, order_by: [asc: q.name])
  def apply_sort(query, "name_desc"), do: from(q in query, order_by: [desc: q.name])
  def apply_sort(query, "created_asc"), do: from(q in query, order_by: [asc: q.inserted_at])
  def apply_sort(query, "created_desc"), do: from(q in query, order_by: [desc: q.inserted_at])
  def apply_sort(query, _), do: query

  def with_preloads(query, preloads) when is_list(preloads) do
    Enum.reduce(preloads, query, fn preload, acc -> from(q in acc, preload: ^[preload]) end)
  end

  def build_report_query(tenant_id, report_type, date_range_start, date_range_end, group_by_field, aggregate_function, having_threshold) do
    from(r in "report_entries", where: r.tenant_id == ^tenant_id and r.type == ^report_type and r.date >= ^date_range_start and r.date <= ^date_range_end, group_by: ^[group_by_field], having: fragment("? > ?", ^aggregate_function, ^having_threshold))
  end

  def build_search_query(search_term, fields, opts) do
    pattern = "%#{String.replace(search_term, "%", "\\%")}%"
    conditions = Enum.map(fields, fn field -> dynamic([q], ilike(field(q, ^field), ^pattern)) end)
    combined_condition = Enum.reduce(conditions, fn cond, acc -> dynamic(^acc or ^cond) end)
    base = from(q in Map.get(opts, :schema, "records"), where: ^combined_condition, limit: ^Map.get(opts, :limit, 50), offset: ^Map.get(opts, :offset, 0))
    base
  end
end
