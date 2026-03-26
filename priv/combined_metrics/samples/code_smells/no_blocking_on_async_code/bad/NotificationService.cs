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

        public void Send(Notification notification)
        {
            var payload = JsonSerializer.Serialize(notification);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            // .Result blocks the calling thread and can cause deadlocks in ASP.NET contexts
            var response = _httpClient.PostAsync($"{_baseUrl}/notify", content).Result;
            response.EnsureSuccessStatusCode();
        }

        public IReadOnlyList<Notification> GetPending(string recipientId)
        {
            // .Result blocks the thread; deadlock-prone in synchronization contexts
            var response = _httpClient.GetAsync(
                $"{_baseUrl}/notifications/pending?recipientId={recipientId}").Result;
            response.EnsureSuccessStatusCode();

            // Another .Result to block on the content read
            var json = response.Content.ReadAsStringAsync().Result;
            var notifications = JsonSerializer.Deserialize<List<Notification>>(json);
            return notifications?.AsReadOnly() ?? new List<Notification>().AsReadOnly();
        }

        public void DispatchBatch(IEnumerable<Notification> notifications)
        {
            var tasks = new List<Task>();
            foreach (var notification in notifications)
                tasks.Add(SendAsync(notification));

            // Task.WaitAll blocks the calling thread
            Task.WaitAll(tasks.ToArray());
        }

        public bool IsReachable()
        {
            try
            {
                // .Wait() blocks and can deadlock
                var responseTask = _httpClient.GetAsync($"{_baseUrl}/health");
                responseTask.Wait();
                return responseTask.Result.IsSuccessStatusCode;
            }
            catch (AggregateException)
            {
                return false;
            }
        }

        private Task SendAsync(Notification notification)
        {
            var payload = JsonSerializer.Serialize(notification);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");
            return _httpClient.PostAsync($"{_baseUrl}/notify", content);
        }
    }
}
