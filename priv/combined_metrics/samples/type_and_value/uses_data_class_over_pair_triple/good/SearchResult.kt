package com.example.search

import java.time.Instant

// Named data class instead of Pair<String, Int>
data class RankedProduct(val productId: String, val score: Int)

// Named data class instead of Triple<String, String, Double>
data class PriceComparison(val productId: String, val supplierId: String, val price: Double)

// Named data class instead of Pair<List<Product>, Int>
data class PaginatedProducts(val products: List<Product>, val totalCount: Int)

// Named data class instead of Pair<Boolean, String?>
data class ValidationResult(val isValid: Boolean, val errorMessage: String?)

class ProductSearchService(
    private val repository: ProductRepository,
    private val scorer: RelevanceScorer
) {

    fun searchRanked(query: String): List<RankedProduct> {
        return repository.search(query)
            .map { product -> RankedProduct(product.id, scorer.score(product, query)) }
            .sortedByDescending { it.score }
    }

    fun findCheapestBySupplier(productId: String): PriceComparison? {
        return repository.findPrices(productId)
            .minByOrNull { it.price }
            ?.let { PriceComparison(productId, it.supplierId, it.price) }
    }

    fun searchPaginated(query: String, page: Int, pageSize: Int): PaginatedProducts {
        val all = repository.search(query)
        val paged = all.drop(page * pageSize).take(pageSize)
        return PaginatedProducts(products = paged, totalCount = all.size)
    }

    fun validateQuery(query: String): ValidationResult {
        if (query.isBlank()) return ValidationResult(false, "Query must not be blank")
        if (query.length < 2) return ValidationResult(false, "Query must be at least 2 characters")
        if (query.length > 200) return ValidationResult(false, "Query must not exceed 200 characters")
        return ValidationResult(true, null)
    }
}
