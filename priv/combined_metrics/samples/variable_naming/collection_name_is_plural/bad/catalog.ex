defmodule Catalog do
  def load_catalog do
    product = fetch_products()
    category = fetch_categories()
    tag = fetch_tags()

    %{products: product, categories: category, tags: tag}
  end

  def filter_by_category(product, category_id) do
    Enum.filter(product, fn item ->
      item.category_id == category_id
    end)
  end

  def apply_tags(product, tag) do
    Enum.map(product, fn item ->
      matching_tag = Enum.filter(tag, fn t -> t.product_id == item.id end)
      Map.put(item, :tags, matching_tag)
    end)
  end

  def group_by_category(product, category) do
    category_map = Map.new(category, fn c -> {c.id, c} end)

    Enum.group_by(product, fn item ->
      cat = Map.get(category_map, item.category_id)
      if cat, do: cat.name, else: :uncategorized
    end)
  end

  def search(product, query) do
    normalized = String.downcase(query)
    Enum.filter(product, fn item ->
      String.contains?(String.downcase(item.name), normalized) ||
        String.contains?(String.downcase(item.description), normalized)
    end)
  end

  def price_range(product, min, max) do
    Enum.filter(product, fn item ->
      item.price >= min && item.price <= max
    end)
  end

  def enrich(product, tag, category) do
    cat_map = Map.new(category, &{&1.id, &1})
    tag_map = Enum.group_by(tag, & &1.product_id)

    Enum.map(product, fn item ->
      cat = Map.get(cat_map, item.category_id, %{})
      associated_tag = Map.get(tag_map, item.id, [])
      item |> Map.put(:category, cat) |> Map.put(:tags, associated_tag)
    end)
  end

  def summarize(product, category) do
    %{
      total_products: length(product),
      total_categories: length(category),
      avg_price: Enum.sum(Enum.map(product, & &1.price)) / max(length(product), 1)
    }
  end

  defp fetch_products, do: []
  defp fetch_categories, do: []
  defp fetch_tags, do: []
end
