using System;
using System.Collections.Generic;

namespace Billing
{
    public class SubscriptionManager
    {
        private readonly ISubscriptionRepository _subscriptionRepository;

        public SubscriptionManager(ISubscriptionRepository subscriptionRepository)
        {
            _subscriptionRepository = subscriptionRepository;
        }

        public Subscription CreateTrialSubscription(int customerId, Plan plan)
        {
            var trialEndDate = DateTimeOffset.UtcNow.AddDays(plan.TrialDurationDays);
            var subscription = new Subscription
            {
                CustomerId = customerId,
                Plan = plan,
                ExpiresAt = trialEndDate,
                IsTrial = true
            };
            _subscriptionRepository.Add(subscription);
            return subscription;
        }

        public void UpgradePlan(int subscriptionId, Plan newPlan)
        {
            var subscription = _subscriptionRepository.GetById(subscriptionId)
                ?? throw new SubscriptionNotFoundException(subscriptionId);

            subscription.Plan = newPlan;
            subscription.UpgradedAt = DateTimeOffset.UtcNow;
            _subscriptionRepository.Update(subscription);
        }

        public IReadOnlyList<Subscription> GetExpiringSoon(int daysUntilExpiration)
        {
            var cutoffDate = DateTimeOffset.UtcNow.AddDays(daysUntilExpiration);
            return _subscriptionRepository.FindExpiringBefore(cutoffDate);
        }

        public bool HasActivePaidSubscription(int customerId)
        {
            var subscription = _subscriptionRepository.FindByCustomer(customerId);
            return subscription != null
                && !subscription.IsTrial
                && subscription.ExpiresAt > DateTimeOffset.UtcNow;
        }

        public void CancelSubscription(int subscriptionId, string cancellationReason)
        {
            var subscription = _subscriptionRepository.GetById(subscriptionId)
                ?? throw new SubscriptionNotFoundException(subscriptionId);

            subscription.CancelledAt = DateTimeOffset.UtcNow;
            subscription.CancellationReason = cancellationReason;
            _subscriptionRepository.Update(subscription);
        }
    }
}
