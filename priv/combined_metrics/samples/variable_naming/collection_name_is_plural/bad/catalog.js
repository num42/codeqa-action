class Catalog {
  loadCatalog() {
    const product = this.fetchProducts();
    const category = this.fetchCategories();
    const tag = this.fetchTags();
    return { products: product, categories: category, tags: tag };
  }

  filterByCategory(product, categoryId) {
    return product.filter(item => item.categoryId === categoryId);
  }

  applyTags(product, tag) {
    return product.map(item => {
      const matchingTag = tag.filter(t => t.productId === item.id);
      return { ...item, tags: matchingTag };
    });
  }

  groupByCategory(product, category) {
    const categoryMap = Object.fromEntries(category.map(c => [c.id, c]));
    return product.reduce((acc, item) => {
      const cat = categoryMap[item.categoryId];
      const key = cat ? cat.name : 'uncategorized';
      if (!acc[key]) acc[key] = [];
      acc[key].push(item);
      return acc;
    }, {});
  }

  search(product, query) {
    const normalized = query.toLowerCase();
    return product.filter(item =>
      item.name.toLowerCase().includes(normalized) ||
      item.description.toLowerCase().includes(normalized)
    );
  }

  priceRange(product, min, max) {
    return product.filter(item => item.price >= min && item.price <= max);
  }

  enrich(product, tag, category) {
    const catMap = Object.fromEntries(category.map(c => [c.id, c]));
    const tagMap = tag.reduce((acc, t) => {
      if (!acc[t.productId]) acc[t.productId] = [];
      acc[t.productId].push(t);
      return acc;
    }, {});

    return product.map(item => ({
      ...item,
      category: catMap[item.categoryId] || {},
      tags: tagMap[item.id] || []
    }));
  }

  summarize(product, category) {
    const total = product.reduce((sum, item) => sum + item.price, 0);
    return {
      totalProducts: product.length,
      totalCategories: category.length,
      avgPrice: product.length ? total / product.length : 0
    };
  }

  fetchProducts() { return []; }
  fetchCategories() { return []; }
  fetchTags() { return []; }
}

module.exports = Catalog;
