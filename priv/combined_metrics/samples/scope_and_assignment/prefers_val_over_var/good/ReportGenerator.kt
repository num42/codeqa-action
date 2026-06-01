package com.example.reporting

import java.time.LocalDate
import java.math.BigDecimal

data class SalesReport(
    val period: DateRange,
    val totalRevenue: BigDecimal,
    val orderCount: Int,
    val averageOrderValue: BigDecimal,
    val topProducts: List<ProductSummary>
)

class ReportGenerator(
    private val orderRepository: OrderRepository,
    private val productRepository: ProductRepository
) {

    fun generateSalesReport(from: LocalDate, to: LocalDate): SalesReport {
        val period = DateRange(from, to)
        val orders = orderRepository.findInRange(from, to)

        // val throughout — nothing is reassigned
        val totalRevenue = orders.sumOf { it.total }
        val orderCount = orders.size
        val averageOrderValue = if (orderCount > 0)
            totalRevenue.divide(BigDecimal.valueOf(orderCount.toLong()))
        else
            BigDecimal.ZERO

        val productFrequency = orders
            .flatMap { it.lineItems }
            .groupingBy { it.productId }
            .eachCount()

        val topProductIds = productFrequency.entries
            .sortedByDescending { it.value }
            .take(5)
            .map { it.key }

        val topProducts = topProductIds
            .mapNotNull { productRepository.findById(it) }
            .map { ProductSummary(it.id, it.name, productFrequency[it.id] ?: 0) }

        return SalesReport(period, totalRevenue, orderCount, averageOrderValue, topProducts)
    }

    fun dailyTotals(from: LocalDate, to: LocalDate): Map<LocalDate, BigDecimal> {
        val orders = orderRepository.findInRange(from, to)
        // val for result — computed once, not mutated
        return orders.groupBy { it.placedAt.toLocalDate() }
            .mapValues { (_, dayOrders) -> dayOrders.sumOf { it.total } }
    }
}
