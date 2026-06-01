package com.example.search

class ProductSearchService(
    private val repository: ProductRepository,
    private val scorer: RelevanceScorer
) {

    // Pair<productId, score> — callers must use .first and .second, intent unclear
    fun searchRanked(query: String): List<Pair<String, Int>> {
        return repository.search(query)
            .map { product -> Pair(product.id, scorer.score(product, query)) }
            .sortedByDescending { it.second }
    }

    // Triple<productId, supplierId, price> — three positional values with no names
    fun findCheapestBySupplier(productId: String): Triple<String, String, Double>? {
        return repository.findPrices(productId)
            .minByOrNull { it.price }
            ?.let { Triple(productId, it.supplierId, it.price) }
    }

    // Pair<List<Product>, Int> — which is the list and which is the count?
    fun searchPaginated(query: String, page: Int, pageSize: Int): Pair<List<Product>, Int> {
        val all = repository.search(query)
        val paged = all.drop(page * pageSize).take(pageSize)
        return Pair(paged, all.size)
    }

    // Pair<Boolean, String?> — callers do result.first instead of result.isValid
    fun validateQuery(query: String): Pair<Boolean, String?> {
        if (query.isBlank()) return Pair(false, "Query must not be blank")
        if (query.length < 2) return Pair(false, "Query must be at least 2 characters")
        if (query.length > 200) return Pair(false, "Query must not exceed 200 characters")
        return Pair(true, null)
    }

    fun topResults(query: String, n: Int): List<Pair<String, Int>> {
        // Accessing .first and .second is opaque at the call site
        return searchRanked(query).take(n).filter { it.second > 0 }
    }
}
