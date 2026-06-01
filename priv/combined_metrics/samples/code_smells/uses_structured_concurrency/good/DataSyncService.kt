package com.example.sync

import kotlinx.coroutines.*

class DataSyncService(
    private val userRepository: UserRepository,
    private val orderRepository: OrderRepository,
    private val inventoryClient: InventoryClient
) {

    // Uses a defined CoroutineScope tied to the service lifecycle
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * Launches a background sync job within the service scope.
     * When the service is stopped, all child coroutines are cancelled via scope.cancel().
     */
    fun startPeriodicSync(): Job = scope.launch {
        while (isActive) {
            syncAll()
            delay(60_000)
        }
    }

    /**
     * Runs all sync tasks concurrently within a single coroutine scope.
     * All tasks are children of the caller's scope — cancellation propagates correctly.
     */
    suspend fun syncAll(): SyncReport = coroutineScope {
        val userSync = async { syncUsers() }
        val orderSync = async { syncOrders() }
        val inventorySync = async { syncInventory() }

        SyncReport(
            usersUpdated = userSync.await(),
            ordersUpdated = orderSync.await(),
            itemsUpdated = inventorySync.await()
        )
    }

    private suspend fun syncUsers(): Int = userRepository.fetchAndUpdate()
    private suspend fun syncOrders(): Int = orderRepository.fetchAndUpdate()
    private suspend fun syncInventory(): Int = inventoryClient.syncAll()

    fun stop() {
        // Cancels all coroutines launched in this scope
        scope.cancel()
    }
}
