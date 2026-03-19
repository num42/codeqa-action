using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;

namespace Payments
{
    public class PaymentGateway
    {
        private readonly HttpClient _httpClient;
        private readonly string _gatewayUrl;

        public PaymentGateway(HttpClient httpClient, string gatewayUrl)
        {
            _httpClient = httpClient;
            _gatewayUrl = gatewayUrl;
        }

        // Async suffix clearly signals the method is asynchronous
        public async Task<ChargeResult> ChargeAsync(PaymentRequest request)
        {
            var payload = JsonSerializer.Serialize(request);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_gatewayUrl}/charge", content);
            var body = await response.Content.ReadAsStringAsync();

            return JsonSerializer.Deserialize<ChargeResult>(body)!;
        }

        public async Task<RefundResult> RefundAsync(string chargeId, decimal amount)
        {
            var payload = JsonSerializer.Serialize(new { chargeId, amount });
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_gatewayUrl}/refund", content);
            var body = await response.Content.ReadAsStringAsync();

            return JsonSerializer.Deserialize<RefundResult>(body)!;
        }

        public async Task<PaymentMethod> GetSavedPaymentMethodAsync(int customerId)
        {
            var response = await _httpClient.GetAsync(
                $"{_gatewayUrl}/customers/{customerId}/payment-method");
            response.EnsureSuccessStatusCode();

            var body = await response.Content.ReadAsStringAsync();
            return JsonSerializer.Deserialize<PaymentMethod>(body)!;
        }

        public async Task<bool> ValidateCardAsync(CardDetails card)
        {
            var payload = JsonSerializer.Serialize(card);
            var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_gatewayUrl}/validate-card", content);
            return response.IsSuccessStatusCode;
        }
    }
}
