class Catalog
  def load_catalog
    products = fetch_products
    categories = fetch_categories
    tags = fetch_tags
    { products: products, categories: categories, tags: tags }
  end

  def filter_by_category(products, category_id)
    products.select { |product| product[:category_id] == category_id }
  end

  def apply_tags(products, tags)
    products.map do |product|
      matching_tags = tags.select { |tag| tag[:product_id] == product[:id] }
      product.merge(tags: matching_tags)
    end
  end

  def group_by_category(products, categories)
    category_map = categories.each_with_object({}) { |category, map| map[category[:id]] = category }
    products.group_by do |product|
      category = category_map[product[:category_id]]
      category ? category[:name] : :uncategorized
    end
  end

  def search(products, query)
    normalized = query.downcase
    products.select do |product|
      product[:name].downcase.include?(normalized) ||
        product[:description].downcase.include?(normalized)
    end
  end

  def price_range(products, min, max)
    products.select { |product| product[:price] >= min && product[:price] <= max }
  end

  def enrich(products, tags, categories)
    category_map = categories.each_with_object({}) { |category, map| map[category[:id]] = category }
    tags_by_product = tags.group_by { |tag| tag[:product_id] }

    products.map do |product|
      category = category_map[product[:category_id]] || {}
      product_tags = tags_by_product[product[:id]] || []
      product.merge(category: category, tags: product_tags)
    end
  end

  def summarize(products, categories)
    total_price = products.sum { |product| product[:price] }
    {
      total_products: products.length,
      total_categories: categories.length,
      avg_price: products.empty? ? 0 : total_price / products.length
    }
  end

  private

  def fetch_products = []
  def fetch_categories = []
  def fetch_tags = []
end
