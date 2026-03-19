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
        // var used even though these values are never reassigned
        var period = DateRange(from, to)
        var orders = orderRepository.findInRange(from, to)
        var totalRevenue = orders.sumOf { it.total }
        var orderCount = orders.size
        var averageOrderValue: BigDecimal

        if (orderCount > 0) {
            averageOrderValue = totalRevenue.divide(BigDecimal.valueOf(orderCount.toLong()))
        } else {
            averageOrderValue = BigDecimal.ZERO
        }

        var productFrequency = orders
            .flatMap { it.lineItems }
            .groupingBy { it.productId }
            .eachCount()

        var topProductIds = productFrequency.entries
            .sortedByDescending { it.value }
            .take(5)
            .map { it.key }

        var topProducts = topProductIds
            .mapNotNull { productRepository.findById(it) }
            .map { ProductSummary(it.id, it.name, productFrequency[it.id] ?: 0) }

        return SalesReport(period, totalRevenue, orderCount, averageOrderValue, topProducts)
    }

    fun dailyTotals(from: LocalDate, to: LocalDate): Map<LocalDate, BigDecimal> {
        var orders = orderRepository.findInRange(from, to)
        var result = mutableMapOf<LocalDate, BigDecimal>()
        // Manual accumulation with var when groupBy + mapValues would suffice
        for (order in orders) {
            var date = order.placedAt.toLocalDate()
            var current = result[date] ?: BigDecimal.ZERO
            result[date] = current.add(order.total)
        }
        return result
    }
}
