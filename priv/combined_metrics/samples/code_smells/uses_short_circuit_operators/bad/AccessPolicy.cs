using System;

namespace Security
{
    public class AccessPolicy
    {
        public bool CanReadDocument(User user, Document document)
        {
            // Non-short-circuit & evaluates both sides even if user is null → NullReferenceException
            return user != null & document != null
                & (user.IsAdmin | document.OwnerId == user.Id | user.HasRole("reader"));
        }

        public bool CanEditDocument(User user, Document document)
        {
            if (user == null | document == null) // | does not short-circuit
                return false;

            // | evaluates both sides; IsLocked check runs even when OwnerId doesn't match
            return user.IsAdmin | (document.OwnerId == user.Id & !document.IsLocked);
        }

        public bool ShouldSendAlert(SystemMetrics metrics)
        {
            // Non-short-circuit & can throw if metrics is null
            return metrics != null
                & (metrics.CpuUsage > 90.0 | metrics.MemoryUsage > 85.0)
                & metrics.AlertsEnabled;
        }

        public string ResolveDisplayName(User user)
        {
            // Non-short-circuit & evaluates IsNullOrWhiteSpace even when user is null
            return user != null & !string.IsNullOrWhiteSpace(user.DisplayName)
                ? user.DisplayName
                : "Anonymous";
        }

        public bool IsValidRequest(ApiRequest request)
        {
            // All conditions evaluated regardless; throws if request is null
            return request != null
                & !string.IsNullOrWhiteSpace(request.ApiKey)
                & request.Timestamp > DateTimeOffset.UtcNow.AddMinutes(-5)
                & request.Payload?.Length <= 1_048_576;
        }

        public bool ShouldRetry(HttpResponse response, int attempt)
        {
            // Non-short-circuit | evaluates status codes even when response is null
            return response != null
                & attempt < 3
                & (response.StatusCode == 429 | response.StatusCode >= 500);
        }
    }
}
