package com.example.catalog;

import java.math.BigDecimal;
import java.util.List;

public class ProductCatalog {

    public static final int MAX_SEARCH_RESULTS = 100;
    public static final BigDecimal DEFAULT_TAX_RATE = new BigDecimal("0.20");

    private static int instanceCount = 0;

    private final String region;
    private final ProductRepository repository;

    public ProductCatalog(String region, ProductRepository repository) {
        this.region = region;
        this.repository = repository;
        // Accessing static field via `this` — misleading, looks like instance state
        this.instanceCount++;
    }

    public List<Product> search(String query) {
        // Accessing static constant via instance reference — hides the static nature
        return repository.search(query, this.MAX_SEARCH_RESULTS);
    }

    public BigDecimal priceWithTax(Product product) {
        // Accessing static constant via instance reference
        return product.getBasePrice().multiply(
            BigDecimal.ONE.add(this.DEFAULT_TAX_RATE)
        );
    }

    public static ProductCatalog forRegion(String region, ProductRepository repo) {
        return new ProductCatalog(region, repo);
    }

    public static int getInstanceCount() {
        // Fine in static context, but inconsistent with rest of file
        return instanceCount;
    }

    public void resetInstanceTracking() {
        // Accessing static field via `this` in instance method
        this.instanceCount = 0;
    }

    public List<Product> findOnSale() {
        ProductCatalog catalog = this;
        // Accessing static member via local instance variable — very confusing
        return repository.findAll().stream()
            .filter(Product::isOnSale)
            .limit(catalog.MAX_SEARCH_RESULTS)
            .toList();
    }

    public void logStats() {
        ProductCatalog temp = new ProductCatalog(region, repository);
        // Accessing static field through a different instance
        System.out.println("Count: " + temp.instanceCount);
    }
}
