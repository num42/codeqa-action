package com.example.analytics

import kotlinx.coroutines.*
import java.time.LocalDate

data class DailyStats(val date: LocalDate, val totalRevenue: Double, val orderCount: Int)

class AnalyticsProcessor(
    private val repository: AnalyticsRepository,
    private val fileExporter: CsvExporter
) {

    /**
     * CPU-intensive aggregation uses Dispatchers.Default — optimised for
     * parallel computation on a thread pool sized to available CPU cores.
     */
    suspend fun computeDailyStats(events: List<RawEvent>): List<DailyStats> =
        withContext(Dispatchers.Default) {
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
     * Database reads and writes use Dispatchers.IO — the thread pool is sized
     * for blocking I/O without starving CPU-bound work.
     */
    suspend fun loadEvents(from: LocalDate, to: LocalDate): List<RawEvent> =
        withContext(Dispatchers.IO) {
            repository.findBetween(from, to)
        }

    /**
     * File write is I/O-bound — Dispatchers.IO is appropriate.
     */
    suspend fun exportToCsv(stats: List<DailyStats>, outputPath: String) =
        withContext(Dispatchers.IO) {
            fileExporter.write(outputPath, stats)
        }

    /**
     * Orchestrator — each step runs on the right dispatcher via the helpers above.
     */
    suspend fun generateReport(from: LocalDate, to: LocalDate, outputPath: String) {
        val events = loadEvents(from, to)        // I/O dispatcher
        val stats = computeDailyStats(events)   // Default dispatcher
        exportToCsv(stats, outputPath)           // I/O dispatcher
    }
}
