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
            // Names describe type, not meaning: "dateTimeOffset" instead of "trialEndDate"
            var dateTimeOffset = DateTimeOffset.UtcNow.AddDays(plan.TrialDurationDays);
            var subscriptionObject = new Subscription  // "Object" suffix adds no meaning
            {
                CustomerId = customerId,
                Plan = plan,
                ExpiresAt = dateTimeOffset,
                IsTrial = true
            };
            _subscriptionRepository.Add(subscriptionObject);
            return subscriptionObject;
        }

        public void UpgradePlan(int subscriptionId, Plan plan)
        {
            // "subscriptionData" describes the type, not the role
            var subscriptionData = _subscriptionRepository.GetById(subscriptionId)
                ?? throw new SubscriptionNotFoundException(subscriptionId);

            subscriptionData.Plan = plan;
            subscriptionData.UpgradedAt = DateTimeOffset.UtcNow;
            _subscriptionRepository.Update(subscriptionData);
        }

        public IReadOnlyList<Subscription> GetExpiringSoon(int days)
        {
            // "dateValue" describes the type — should be "cutoffDate"
            var dateValue = DateTimeOffset.UtcNow.AddDays(days);
            return _subscriptionRepository.FindExpiringBefore(dateValue);
        }

        public bool HasActivePaidSubscription(int customerId)
        {
            // "subscriptionRecord" — type-based name for what is just "subscription"
            var subscriptionRecord = _subscriptionRepository.FindByCustomer(customerId);
            // "boolResult" — type name instead of "hasActive" or just returning inline
            bool boolResult = subscriptionRecord != null
                && !subscriptionRecord.IsTrial
                && subscriptionRecord.ExpiresAt > DateTimeOffset.UtcNow;
            return boolResult;
        }

        public void CancelSubscription(int subscriptionId, string stringReason) // type name as param
        {
            var subscriptionInstance = _subscriptionRepository.GetById(subscriptionId)
                ?? throw new SubscriptionNotFoundException(subscriptionId);

            // "dateTimeValue" instead of "cancelledAt"
            var dateTimeValue = DateTimeOffset.UtcNow;
            subscriptionInstance.CancelledAt = dateTimeValue;
            subscriptionInstance.CancellationReason = stringReason;
            _subscriptionRepository.Update(subscriptionInstance);
        }
    }
}
