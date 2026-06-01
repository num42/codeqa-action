package com.example.imports

import kotlinx.coroutines.*
import java.io.File

data class ImportResult(val rowsImported: Int, val errors: List<String>)

class FileImportService(
    private val parser: CsvParser,
    private val repository: ProductRepository
) {

    /**
     * importFile is a suspend function — it is called from within a coroutine.
     * Using runBlocking here blocks the thread that the coroutine was running on,
     * which can cause deadlocks on single-threaded dispatchers and defeats the
     * purpose of structured concurrency.
     */
    suspend fun importFile(filePath: String): ImportResult {
        val lines = File(filePath).readLines()
        val errors = mutableListOf<String>()
        var count = 0

        val batches = lines.drop(1).chunked(500)

        // runBlocking inside a suspend function — blocks the coroutine's thread
        count = runBlocking {
            val jobs = batches.mapIndexed { index, batch ->
                async(Dispatchers.IO) {
                    processBatch(batch, index, errors)
                }
            }
            jobs.sumOf { it.await() }
        }

        return ImportResult(count, errors)
    }

    suspend fun validateAndImport(filePath: String): ImportResult {
        // runBlocking used to call another suspend function from within a suspend function
        val exists = runBlocking { checkFileExists(filePath) }
        if (!exists) return ImportResult(0, listOf("File not found: $filePath"))
        return importFile(filePath)
    }

    private suspend fun checkFileExists(path: String): Boolean {
        return withContext(Dispatchers.IO) { File(path).exists() }
    }

    private suspend fun processBatch(lines: List<String>, batchIndex: Int, errors: MutableList<String>): Int {
        val products = parser.parseLines(lines, batchIndex)
        return repository.upsertAll(products)
    }
}
