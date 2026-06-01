defmodule Catalog do
  def load_catalog do
    products = fetch_products()
    categories = fetch_categories()
    tags = fetch_tags()

    %{products: products, categories: categories, tags: tags}
  end

  def filter_by_category(products, category_id) do
    Enum.filter(products, fn product ->
      product.category_id == category_id
    end)
  end

  def apply_tags(products, tags) do
    Enum.map(products, fn product ->
      matching_tags = Enum.filter(tags, fn tag -> tag.product_id == product.id end)
      Map.put(product, :tags, matching_tags)
    end)
  end

  def group_by_category(products, categories) do
    category_map = Map.new(categories, fn category -> {category.id, category} end)

    Enum.group_by(products, fn product ->
      category = Map.get(category_map, product.category_id)
      if category, do: category.name, else: :uncategorized
    end)
  end

  def search(products, query) do
    normalized = String.downcase(query)
    Enum.filter(products, fn product ->
      String.contains?(String.downcase(product.name), normalized) ||
        String.contains?(String.downcase(product.description), normalized)
    end)
  end

  def price_range(products, min, max) do
    Enum.filter(products, fn product ->
      product.price >= min && product.price <= max
    end)
  end

  def enrich(products, tags, categories) do
    category_map = Map.new(categories, &{&1.id, &1})
    tags_by_product = Enum.group_by(tags, & &1.product_id)

    Enum.map(products, fn product ->
      category = Map.get(category_map, product.category_id, %{})
      product_tags = Map.get(tags_by_product, product.id, [])
      product |> Map.put(:category, category) |> Map.put(:tags, product_tags)
    end)
  end

  def summarize(products, categories) do
    %{
      total_products: length(products),
      total_categories: length(categories),
      avg_price: Enum.sum(Enum.map(products, & &1.price)) / max(length(products), 1)
    }
  end

  defp fetch_products, do: []
  defp fetch_categories, do: []
  defp fetch_tags, do: []
end
