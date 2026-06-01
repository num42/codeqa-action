class Catalog {
  loadCatalog() {
    const products = this.fetchProducts();
    const categories = this.fetchCategories();
    const tags = this.fetchTags();
    return { products, categories, tags };
  }

  filterByCategory(products, categoryId) {
    return products.filter(product => product.categoryId === categoryId);
  }

  applyTags(products, tags) {
    return products.map(product => {
      const matchingTags = tags.filter(tag => tag.productId === product.id);
      return { ...product, tags: matchingTags };
    });
  }

  groupByCategory(products, categories) {
    const categoryMap = Object.fromEntries(categories.map(category => [category.id, category]));
    return products.reduce((grouped, product) => {
      const category = categoryMap[product.categoryId];
      const key = category ? category.name : 'uncategorized';
      if (!grouped[key]) grouped[key] = [];
      grouped[key].push(product);
      return grouped;
    }, {});
  }

  search(products, query) {
    const normalized = query.toLowerCase();
    return products.filter(product =>
      product.name.toLowerCase().includes(normalized) ||
      product.description.toLowerCase().includes(normalized)
    );
  }

  priceRange(products, min, max) {
    return products.filter(product => product.price >= min && product.price <= max);
  }

  enrich(products, tags, categories) {
    const categoryMap = Object.fromEntries(categories.map(c => [c.id, c]));
    const tagsByProduct = tags.reduce((acc, tag) => {
      if (!acc[tag.productId]) acc[tag.productId] = [];
      acc[tag.productId].push(tag);
      return acc;
    }, {});

    return products.map(product => ({
      ...product,
      category: categoryMap[product.categoryId] || {},
      tags: tagsByProduct[product.id] || []
    }));
  }

  summarize(products, categories) {
    const totalPrice = products.reduce((sum, product) => sum + product.price, 0);
    return {
      totalProducts: products.length,
      totalCategories: categories.length,
      avgPrice: products.length ? totalPrice / products.length : 0
    };
  }

  fetchProducts() { return []; }
  fetchCategories() { return []; }
  fetchTags() { return []; }
}

module.exports = Catalog;
