package com.example.orders

data class Address(val street: String, val city: String, val postalCode: String)
data class Customer(val id: String, val name: String, val address: Address?)
data class Order(val id: String, val customer: Customer?, val notes: String?)

class OrderManager(private val repository: OrderRepository) {

    fun getShippingCity(orderId: String): String? {
        // Safe call chain — concise and null-safe without nested if checks
        return repository.findById(orderId)?.customer?.address?.city
    }

    fun getOrderNoteLength(orderId: String): Int {
        // Safe call with Elvis for default
        return repository.findById(orderId)?.notes?.length ?: 0
    }

    fun formatShippingLabel(orderId: String): String? {
        val order = repository.findById(orderId) ?: return null
        // Safe call chain instead of repeated null checks
        val city = order.customer?.address?.city ?: return null
        val postalCode = order.customer?.address?.postalCode ?: return null
        val customerName = order.customer?.name ?: "Unknown"
        return "$customerName, $city $postalCode"
    }

    fun notifyCustomer(orderId: String, message: String): Boolean {
        // Safe call — no NPE risk, cleanly returns null/false if absent
        val customerId = repository.findById(orderId)?.customer?.id ?: return false
        return notificationService.send(customerId, message)
    }

    fun upperCaseNotes(orderId: String): String? {
        // Chained safe calls — readable transformation pipeline
        return repository.findById(orderId)?.notes?.uppercase()?.trim()
    }

    private val notificationService = NotificationService()
}
