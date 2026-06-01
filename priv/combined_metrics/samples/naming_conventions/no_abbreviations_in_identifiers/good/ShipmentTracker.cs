using System;
using System.Collections.Generic;

namespace Shipping
{
    public class ShipmentTracker
    {
        private readonly IShipmentRepository _shipmentRepository;
        private readonly INotificationService _notificationService;

        public ShipmentTracker(
            IShipmentRepository shipmentRepository,
            INotificationService notificationService)
        {
            _shipmentRepository = shipmentRepository;
            _notificationService = notificationService;
        }

        public ShipmentStatus GetCurrentStatus(string trackingNumber)
        {
            var shipment = _shipmentRepository.FindByTrackingNumber(trackingNumber)
                ?? throw new ShipmentNotFoundException(trackingNumber);

            return shipment.CurrentStatus;
        }

        public void RecordDeliveryAttempt(string trackingNumber, DeliveryAttemptDetails attemptDetails)
        {
            var shipment = _shipmentRepository.FindByTrackingNumber(trackingNumber)
                ?? throw new ShipmentNotFoundException(trackingNumber);

            shipment.DeliveryAttempts.Add(attemptDetails);
            _shipmentRepository.Update(shipment);

            if (attemptDetails.WasSuccessful)
            {
                shipment.MarkDelivered(attemptDetails.DeliveredAt);
                _notificationService.SendDeliveryConfirmation(shipment.RecipientEmail, trackingNumber);
            }
            else
            {
                _notificationService.SendFailedAttemptNotification(
                    shipment.RecipientEmail, trackingNumber, attemptDetails.FailureReason);
            }
        }

        public IReadOnlyList<Shipment> GetShipmentsWithEstimatedDeliveryBefore(DateTimeOffset deadline)
        {
            return _shipmentRepository.FindByEstimatedDeliveryBefore(deadline);
        }

        public ShipmentSummary GenerateSummaryForDateRange(DateTimeOffset startDate, DateTimeOffset endDate)
        {
            var shipments = _shipmentRepository.FindByDispatchedBetween(startDate, endDate);
            int deliveredCount = 0;
            int pendingCount = 0;

            foreach (var shipment in shipments)
            {
                if (shipment.CurrentStatus == ShipmentStatus.Delivered) deliveredCount++;
                else pendingCount++;
            }

            return new ShipmentSummary(deliveredCount, pendingCount, startDate, endDate);
        }
    }
}
