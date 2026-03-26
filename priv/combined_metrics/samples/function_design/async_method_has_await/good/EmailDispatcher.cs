using System.Collections.Generic;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

namespace Email
{
    public class EmailDispatcher
    {
        private readonly HttpClient _httpClient;
        private readonly string _apiEndpoint;

        public EmailDispatcher(HttpClient httpClient, string apiEndpoint)
        {
            _httpClient = httpClient;
            _apiEndpoint = apiEndpoint;
        }

        public async Task<SendResult> SendAsync(EmailMessage message)
        {
            var payload = JsonSerializer.Serialize(message);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            // Contains genuine await — truly async I/O operation
            var response = await _httpClient.PostAsync(_apiEndpoint, content);
            var body = await response.Content.ReadAsStringAsync();

            return response.IsSuccessStatusCode
                ? SendResult.Success()
                : SendResult.Failure(body);
        }

        public async Task<IReadOnlyList<SendResult>> SendBatchAsync(IEnumerable<EmailMessage> messages)
        {
            var tasks = new List<Task<SendResult>>();
            foreach (var message in messages)
                tasks.Add(SendAsync(message));

            // Awaits all concurrent I/O operations
            var results = await Task.WhenAll(tasks);
            return results;
        }

        public async Task<bool> PingAsync()
        {
            // Contains await — not just wrapping sync work
            var response = await _httpClient.GetAsync(_apiEndpoint + "/ping");
            return response.IsSuccessStatusCode;
        }

        public async Task<EmailQuota> GetRemainingQuotaAsync()
        {
            var response = await _httpClient.GetAsync(_apiEndpoint + "/quota");
            response.EnsureSuccessStatusCode();
            var json = await response.Content.ReadAsStringAsync();
            return JsonSerializer.Deserialize<EmailQuota>(json)!;
        }
    }
}
