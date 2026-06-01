package com.example.sync

import kotlinx.coroutines.*

class DataSyncService(
    private val userRepository: UserRepository,
    private val orderRepository: OrderRepository,
    private val inventoryClient: InventoryClient
) {

    /**
     * Launches coroutines using GlobalScope — they are not tied to any lifecycle.
     * If the service is destroyed or the app shuts down, these coroutines keep running
     * and cannot be cancelled as a group.
     */
    fun startPeriodicSync(): Job = GlobalScope.launch(Dispatchers.IO) {
        while (isActive) {
            syncAll()
            delay(60_000)
        }
    }

    /**
     * Each task is launched into GlobalScope independently.
     * There is no parent scope to cancel them together, and exceptions
     * in one do not cancel the others.
     */
    suspend fun syncAll(): SyncReport {
        val userJob = GlobalScope.async(Dispatchers.IO) { syncUsers() }
        val orderJob = GlobalScope.async(Dispatchers.IO) { syncOrders() }
        val inventoryJob = GlobalScope.async(Dispatchers.IO) { syncInventory() }

        return SyncReport(
            usersUpdated = userJob.await(),
            ordersUpdated = orderJob.await(),
            itemsUpdated = inventoryJob.await()
        )
    }

    private suspend fun syncUsers(): Int = userRepository.fetchAndUpdate()
    private suspend fun syncOrders(): Int = orderRepository.fetchAndUpdate()
    private suspend fun syncInventory(): Int = inventoryClient.syncAll()

    fun stop() {
        // No-op — nothing to cancel because GlobalScope outlives everything
    }
}
