package com.example.imports

import kotlinx.coroutines.*
import java.io.File

data class ImportResult(val rowsImported: Int, val errors: List<String>)

class FileImportService(
    private val parser: CsvParser,
    private val repository: ProductRepository
) {

    /**
     * Top-level entry point — runBlocking here is acceptable because this is
     * the boundary between the non-coroutine world (e.g. a CLI main function)
     * and the coroutine world. It is NOT inside an existing coroutine.
     */
    fun importFromCli(filePath: String): ImportResult = runBlocking {
        importFile(filePath)
    }

    /**
     * The actual work is a proper suspend function.
     * Any coroutine-aware caller (HTTP handler, scheduled job) calls this directly
     * without incurring the overhead or blocking of runBlocking.
     */
    suspend fun importFile(filePath: String): ImportResult = coroutineScope {
        val lines = File(filePath).readLines()
        val errors = mutableListOf<String>()
        var count = 0

        val batches = lines.drop(1).chunked(500)
        val jobs = batches.mapIndexed { index, batch ->
            async(Dispatchers.IO) {
                processBatch(batch, index, errors)
            }
        }

        count = jobs.sumOf { it.await() }
        ImportResult(count, errors)
    }

    private suspend fun processBatch(
        lines: List<String>,
        batchIndex: Int,
        errors: MutableList<String>
    ): Int {
        val products = parser.parseLines(lines, batchIndex)
        return repository.upsertAll(products)
    }
}
