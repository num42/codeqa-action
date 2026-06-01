package com.example.subscriptions

import java.time.LocalDate

class SubscriptionService(private val repository: SubscriptionRepository) {

    fun createSubscription(userId: String, planId: String, referralCode: String? = null): Subscription {
        val plan = repository.findPlan(planId) ?: throw PlanNotFoundException(planId)
        val subscription = Subscription(userId = userId, planId = planId, referralCode = referralCode)
        return repository.save(subscription)
    }

    fun transferSubscription(fromUserId: String, toUserId: String, subscriptionId: String): Boolean {
        val sub = repository.findById(subscriptionId) ?: return false
        if (sub.userId != fromUserId) return false
        val transferred = sub.copy(userId = toUserId)
        repository.save(transferred)
        return true
    }

    fun scheduleRenewal(subscriptionId: String, renewalDate: LocalDate, graceEndDate: LocalDate) {
        val sub = repository.findById(subscriptionId) ?: return
        val scheduled = sub.copy(nextRenewalDate = renewalDate, graceEndDate = graceEndDate)
        repository.save(scheduled)
    }
}

fun main() {
    val service = SubscriptionService(SubscriptionRepository())

    // No named arguments — "user-123", "plan-pro", "FRIEND10" are positional, easy to swap
    service.createSubscription("user-123", "plan-pro", "FRIEND10")

    // fromUserId and toUserId have the same type — easy to accidentally swap them
    service.transferSubscription("user-abc", "user-xyz", "sub-999")

    // Two LocalDate params next to each other — renewalDate and graceEndDate order is guesswork
    service.scheduleRenewal("sub-001", LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 15))
}
