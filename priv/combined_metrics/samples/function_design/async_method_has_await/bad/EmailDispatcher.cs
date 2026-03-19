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

        // async keyword with no await — compiles with a warning; runs synchronously
        public async Task<SendResult> SendAsync(EmailMessage message)
        {
            var payload = JsonSerializer.Serialize(message);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            // Missing await — blocks synchronously, defeats the purpose of async
            var response = _httpClient.PostAsync(_apiEndpoint, content).Result;
            var body = response.Content.ReadAsStringAsync().Result;

            return response.IsSuccessStatusCode
                ? SendResult.Success()
                : SendResult.Failure(body);
        }

        // async but delegates all work to non-awaited helpers — no suspension point
        public async Task<bool> PingAsync()
        {
            return CheckPing(); // synchronous; async here adds overhead with no benefit
        }

        // async method that just wraps a completed task — should not be async
        public async Task<string> GetApiEndpointAsync()
        {
            return _apiEndpoint; // no await, just returns a value
        }

        // async that does no I/O at all — the async machinery is pure overhead
        public async Task LogMetricsAsync(int sent, int failed)
        {
            var summary = $"Sent: {sent}, Failed: {failed}";
            System.Console.WriteLine(summary);
        }

        private bool CheckPing()
        {
            var response = _httpClient.GetAsync(_apiEndpoint + "/ping").Result;
            return response.IsSuccessStatusCode;
        }
    }
}
