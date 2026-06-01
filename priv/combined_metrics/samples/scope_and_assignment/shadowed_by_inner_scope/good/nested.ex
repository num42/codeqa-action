defmodule Data.Nested do
  @moduledoc """
  Nested data transformation — GOOD: inner scopes use distinct variable names.
  """

  def transform_catalog(catalog) do
    default_item = catalog.default_item

    enriched_items =
      Enum.map(catalog.items, fn catalog_item ->
        enriched_variants =
          Enum.map(catalog_item.tags, fn tag ->
            Map.put(catalog_item, :primary_tag, tag)
          end)

        %{id: catalog_item.id, enriched: enriched_variants}
      end)

    {default_item, enriched_items}
  end

  def process_orders(user, orders) do
    first_order = List.first(orders)

    summaries =
      Enum.map(orders, fn order ->
        taxed_lines =
          Enum.map(order.line_items, fn line_item ->
            Map.put(line_item, :taxed_price, line_item.price * 1.08)
          end)

        Map.put(order, :lines, taxed_lines)
      end)

    %{user: user.id, first: first_order, summaries: summaries}
  end

  def flatten_groups(groups) do
    first_group = hd(groups)

    all_members =
      Enum.flat_map(groups, fn group ->
        group_summary = Map.take(group, [:id, :name])

        Enum.map(group.members, fn member ->
          Map.put(member, :group, group_summary)
        end)
      end)

    {first_group.id, all_members}
  end
end
