package com.example.orders

data class Address(val street: String, val city: String, val postalCode: String)
data class Customer(val id: String, val name: String, val address: Address?)
data class Order(val id: String, val customer: Customer?, val notes: String?)

class OrderManager(private val repository: OrderRepository) {

    fun getShippingCity(orderId: String): String? {
        // Verbose nested null checks instead of safe call chain
        val order = repository.findById(orderId)
        if (order != null) {
            val customer = order.customer
            if (customer != null) {
                val address = customer.address
                if (address != null) {
                    return address.city
                }
            }
        }
        return null
    }

    fun getOrderNoteLength(orderId: String): Int {
        val order = repository.findById(orderId)
        if (order != null) {
            val notes = order.notes
            if (notes != null) {
                return notes.length
            }
        }
        return 0
    }

    fun formatShippingLabel(orderId: String): String? {
        val order = repository.findById(orderId)
        if (order != null) {
            val customer = order.customer
            if (customer != null) {
                val address = customer.address
                if (address != null) {
                    return "${customer.name}, ${address.city} ${address.postalCode}"
                }
            }
        }
        return null
    }

    fun notifyCustomer(orderId: String, message: String): Boolean {
        val order = repository.findById(orderId)
        if (order != null) {
            val customer = order.customer
            if (customer != null) {
                return notificationService.send(customer.id, message)
            }
        }
        return false
    }

    private val notificationService = NotificationService()
}
