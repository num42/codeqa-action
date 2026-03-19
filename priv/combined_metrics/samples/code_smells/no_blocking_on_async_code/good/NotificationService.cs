using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

namespace Notifications
{
    public class NotificationService
    {
        private readonly HttpClient _httpClient;
        private readonly string _baseUrl;

        public NotificationService(HttpClient httpClient, string baseUrl)
        {
            _httpClient = httpClient;
            _baseUrl = baseUrl;
        }

        public async Task SendAsync(Notification notification)
        {
            var payload = JsonSerializer.Serialize(notification);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_baseUrl}/notify", content);
            response.EnsureSuccessStatusCode();
        }

        public async Task<IReadOnlyList<Notification>> GetPendingAsync(string recipientId)
        {
            var response = await _httpClient.GetAsync(
                $"{_baseUrl}/notifications/pending?recipientId={recipientId}");
            response.EnsureSuccessStatusCode();

            var json = await response.Content.ReadAsStringAsync();
            var notifications = JsonSerializer.Deserialize<List<Notification>>(json);
            return notifications?.AsReadOnly() ?? new List<Notification>().AsReadOnly();
        }

        public async Task DispatchBatchAsync(IEnumerable<Notification> notifications)
        {
            var tasks = new List<Task>();
            foreach (var notification in notifications)
                tasks.Add(SendAsync(notification));

            await Task.WhenAll(tasks);
        }

        public async Task<bool> IsReachableAsync()
        {
            try
            {
                var response = await _httpClient.GetAsync($"{_baseUrl}/health");
                return response.IsSuccessStatusCode;
            }
            catch (HttpRequestException)
            {
                return false;
            }
        }
    }
}
