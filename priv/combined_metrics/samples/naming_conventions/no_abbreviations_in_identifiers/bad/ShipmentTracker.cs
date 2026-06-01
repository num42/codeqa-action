using System;
using System.Collections.Generic;

namespace Shipping
{
    public class ShipmentTracker
    {
        private readonly IShipmentRepository _repo;     // abbreviated
        private readonly INotificationService _notifSvc; // abbreviated

        public ShipmentTracker(IShipmentRepository repo, INotificationService notifSvc)
        {
            _repo = repo;
            _notifSvc = notifSvc;
        }

        public ShipmentStatus GetCurrStatus(string trkNum) // abbreviated
        {
            var shpmnt = _repo.FindByTrackingNumber(trkNum) // abbreviated
                ?? throw new ShipmentNotFoundException(trkNum);

            return shpmnt.CurrentStatus;
        }

        public void RecordDlvAttempt(string trkNum, DeliveryAttemptDetails dtls) // abbreviated
        {
            var shpmnt = _repo.FindByTrackingNumber(trkNum)
                ?? throw new ShipmentNotFoundException(trkNum);

            shpmnt.DeliveryAttempts.Add(dtls);
            _repo.Update(shpmnt);

            if (dtls.WasSuccessful)
            {
                shpmnt.MarkDelivered(dtls.DeliveredAt);
                _notifSvc.SendDeliveryConfirmation(shpmnt.RecipientEmail, trkNum);
            }
            else
            {
                _notifSvc.SendFailedAttemptNotification(
                    shpmnt.RecipientEmail, trkNum, dtls.FailureReason);
            }
        }

        public IReadOnlyList<Shipment> GetShipmentsWithEstDlvBefore(DateTimeOffset dl) // abbreviated
        {
            return _repo.FindByEstimatedDeliveryBefore(dl);
        }

        public ShipmentSummary GenSummForDtRng(DateTimeOffset stDt, DateTimeOffset endDt) // abbreviated
        {
            var shpmnts = _repo.FindByDispatchedBetween(stDt, endDt);
            int dlvdCnt = 0;   // abbreviated
            int pendCnt = 0;   // abbreviated

            foreach (var s in shpmnts)
            {
                if (s.CurrentStatus == ShipmentStatus.Delivered) dlvdCnt++;
                else pendCnt++;
            }

            return new ShipmentSummary(dlvdCnt, pendCnt, stDt, endDt);
        }
    }
}
