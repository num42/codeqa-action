package com.example.analytics

import kotlinx.coroutines.*
import java.time.LocalDate

data class DailyStats(val date: LocalDate, val totalRevenue: Double, val orderCount: Int)

class AnalyticsProcessor(
    private val repository: AnalyticsRepository,
    private val fileExporter: CsvExporter
) {

    /**
     * CPU-intensive computation incorrectly uses Dispatchers.IO.
     * IO's thread pool is designed for blocking calls — using it for heavy
     * CPU work starves I/O threads and misses parallelism optimisations.
     */
    suspend fun computeDailyStats(events: List<RawEvent>): List<DailyStats> =
        withContext(Dispatchers.IO) {   // Wrong dispatcher for CPU work
            events
                .groupBy { it.occurredAt.toLocalDate() }
                .map { (date, dayEvents) ->
                    val revenue = dayEvents.sumOf { it.amount }
                    val orders = dayEvents.count { it.type == "ORDER_PLACED" }
                    DailyStats(date, revenue, orders)
                }
                .sortedBy { it.date }
        }

    /**
     * Database access incorrectly uses Dispatchers.Default.
     * Default is for CPU-bound work; blocking DB calls here will exhaust
     * the limited Default thread pool and degrade all CPU-bound tasks.
     */
    suspend fun loadEvents(from: LocalDate, to: LocalDate): List<RawEvent> =
        withContext(Dispatchers.Default) {  // Wrong dispatcher for I/O
            repository.findBetween(from, to)
        }

    /**
     * File write runs on Dispatchers.Default — blocking I/O on a CPU dispatcher
     * ties up a thread that should be doing computation.
     */
    suspend fun exportToCsv(stats: List<DailyStats>, outputPath: String) =
        withContext(Dispatchers.Default) {  // Wrong dispatcher for file I/O
            fileExporter.write(outputPath, stats)
        }

    suspend fun generateReport(from: LocalDate, to: LocalDate, outputPath: String) {
        val events = loadEvents(from, to)
        val stats = computeDailyStats(events)
        exportToCsv(stats, outputPath)
    }
}
