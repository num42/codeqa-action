class Catalog
  def load_catalog
    product = fetch_products
    category = fetch_categories
    tag = fetch_tags
    { products: product, categories: category, tags: tag }
  end

  def filter_by_category(product, category_id)
    product.select { |item| item[:category_id] == category_id }
  end

  def apply_tags(product, tag)
    product.map do |item|
      matching_tag = tag.select { |t| t[:product_id] == item[:id] }
      item.merge(tags: matching_tag)
    end
  end

  def group_by_category(product, category)
    category_map = category.each_with_object({}) { |c, h| h[c[:id]] = c }
    product.group_by do |item|
      cat = category_map[item[:category_id]]
      cat ? cat[:name] : :uncategorized
    end
  end

  def search(product, query)
    normalized = query.downcase
    product.select do |item|
      item[:name].downcase.include?(normalized) ||
        item[:description].downcase.include?(normalized)
    end
  end

  def price_range(product, min, max)
    product.select { |item| item[:price] >= min && item[:price] <= max }
  end

  def enrich(product, tag, category)
    cat_map = category.each_with_object({}) { |c, h| h[c[:id]] = c }
    tag_map = tag.group_by { |t| t[:product_id] }

    product.map do |item|
      cat = cat_map[item[:category_id]] || {}
      associated_tag = tag_map[item[:id]] || []
      item.merge(category: cat, tags: associated_tag)
    end
  end

  def summarize(product, category)
    total = product.sum { |item| item[:price] }
    {
      total_products: product.length,
      total_categories: category.length,
      avg_price: product.empty? ? 0 : total / product.length
    }
  end

  private

  def fetch_products = []
  def fetch_categories = []
  def fetch_tags = []
end
