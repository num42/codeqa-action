package com.example.subscriptions

import java.time.LocalDate

class SubscriptionService(private val repository: SubscriptionRepository) {

    fun createSubscription(
        userId: String,
        planId: String,
        referralCode: String? = null
    ): Subscription {
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

    fun findInDateRange(startDate: LocalDate, endDate: LocalDate): List<Subscription> {
        return repository.findCreatedBetween(startDate = startDate, endDate = endDate)
    }
}

fun main() {
    val service = SubscriptionService(SubscriptionRepository())

    // Named arguments make the call site unambiguous for multiple String params
    service.createSubscription(
        userId = "user-123",
        planId = "plan-pro",
        referralCode = "FRIEND10"
    )

    service.transferSubscription(
        fromUserId = "user-abc",
        toUserId = "user-xyz",
        subscriptionId = "sub-999"
    )

    service.scheduleRenewal(
        subscriptionId = "sub-001",
        renewalDate = LocalDate.of(2026, 4, 1),
        graceEndDate = LocalDate.of(2026, 4, 15)
    )
}
