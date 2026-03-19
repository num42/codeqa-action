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
        ProductCatalog.instanceCount++;
    }

    public List<Product> search(String query) {
        // Accessing static constant via class name
        return repository.search(query, ProductCatalog.MAX_SEARCH_RESULTS);
    }

    public BigDecimal priceWithTax(Product product) {
        // Accessing static constant via class name
        return product.getBasePrice().multiply(
            BigDecimal.ONE.add(ProductCatalog.DEFAULT_TAX_RATE)
        );
    }

    public static ProductCatalog forRegion(String region, ProductRepository repo) {
        return new ProductCatalog(region, repo);
    }

    public static int getInstanceCount() {
        // Accessing static field via class name inside static method
        return ProductCatalog.instanceCount;
    }

    public void resetInstanceTracking() {
        // Static field accessed via class name even from instance method
        ProductCatalog.instanceCount = 0;
    }

    public Product findBySkuOrThrow(String sku) {
        Product product = repository.findBySku(sku);
        if (product == null) {
            throw new ProductNotFoundException(sku);
        }
        return product;
    }

    public List<Product> findOnSale() {
        return repository.findAll().stream()
            .filter(Product::isOnSale)
            .limit(ProductCatalog.MAX_SEARCH_RESULTS)
            .toList();
    }
}
