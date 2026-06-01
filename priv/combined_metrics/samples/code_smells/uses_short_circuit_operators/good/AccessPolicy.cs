using System;

namespace Security
{
    public class AccessPolicy
    {
        public bool CanReadDocument(User user, Document document)
        {
            // Short-circuit: if user is null, the rest is never evaluated
            return user != null && document != null
                && (user.IsAdmin || document.OwnerId == user.Id || user.HasRole("reader"));
        }

        public bool CanEditDocument(User user, Document document)
        {
            if (user == null || document == null)
                return false;

            // Short-circuit: IsAdmin check avoids evaluating the more expensive checks
            return user.IsAdmin || (document.OwnerId == user.Id && !document.IsLocked);
        }

        public bool ShouldSendAlert(SystemMetrics metrics)
        {
            // Short-circuit: if metrics is null, subsequent property access is skipped
            return metrics != null
                && (metrics.CpuUsage > 90.0 || metrics.MemoryUsage > 85.0)
                && metrics.AlertsEnabled;
        }

        public string ResolveDisplayName(User user)
        {
            // Short-circuit null coalescing with && guards
            return user != null && !string.IsNullOrWhiteSpace(user.DisplayName)
                ? user.DisplayName
                : "Anonymous";
        }

        public bool IsValidRequest(ApiRequest request)
        {
            return request != null
                && !string.IsNullOrWhiteSpace(request.ApiKey)
                && request.Timestamp > DateTimeOffset.UtcNow.AddMinutes(-5)
                && request.Payload?.Length <= 1_048_576;
        }

        public bool ShouldRetry(HttpResponse response, int attempt)
        {
            return response != null
                && attempt < 3
                && (response.StatusCode == 429 || response.StatusCode >= 500);
        }
    }
}
