defmodule Data.Nested do
  @moduledoc """
  Nested data transformation — BAD: inner scopes shadow outer variable names.
  """

  def transform_catalog(catalog) do
    items = catalog.items

    # outer `item` variable
    item = catalog.default_item

    result =
      Enum.map(items, fn item ->
        # `item` shadows the outer `item` binding above
        tags = item.tags

        enriched =
          Enum.map(tags, fn tag ->
            # `tag` is fine, but reusing `item` inside map over tags shadows again
            item = Map.put(item, :primary_tag, tag)
            item
          end)

        %{id: item.id, enriched: enriched}
      end)

    {item, result}
  end

  def process_orders(user, orders) do
    # outer `order`
    order = List.first(orders)

    summaries =
      Enum.map(orders, fn order ->
        # `order` shadows outer binding
        lines =
          Enum.map(order.line_items, fn item ->
            # `item` is new here, but then rebound below
            item = Map.put(item, :taxed_price, item.price * 1.08)
            item
          end)

        Map.put(order, :lines, lines)
      end)

    %{user: user.id, first: order, summaries: summaries}
  end

  def flatten_groups(groups) do
    # outer `group`
    group = hd(groups)

    all =
      Enum.flat_map(groups, fn group ->
        # `group` shadows outer
        Enum.map(group.members, fn member ->
          group = Map.take(group, [:id, :name])
          # `group` shadowed again inside inner Enum.map
          Map.put(member, :group, group)
        end)
      end)

    {group.id, all}
  end
end
