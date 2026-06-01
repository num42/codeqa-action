<?php

declare(strict_types=1);

namespace App\Payment;

// Method names use camelCase — PSR-1
class PaymentGateway
{
    private string $apiKey;
    private string $baseUrl;
    private int $requestCount = 0;

    public function __construct(string $apiKey, string $baseUrl)
    {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
    }

    public function chargeCard(int $amountCents, string $token): ChargeResult
    {
        $this->requestCount++;
        $response = $this->sendRequest('POST', '/v1/charges', [
            'amount' => $amountCents,
            'source' => $token,
        ]);

        return new ChargeResult(transactionId: $response['id']);
    }

    public function issueRefund(string $transactionId, int $amountCents): RefundResult
    {
        $response = $this->sendRequest('POST', '/v1/refunds', [
            'transaction_id' => $transactionId,
            'amount'         => $amountCents,
        ]);

        return new RefundResult(refundId: $response['refund_id']);
    }

    public function getTransactionStatus(string $transactionId): string
    {
        $response = $this->sendRequest('GET', "/v1/charges/{$transactionId}");

        return $response['status'];
    }

    public function validateWebhookSignature(string $payload, string $signature): bool
    {
        $expected = hash_hmac('sha256', $payload, $this->apiKey);

        return hash_equals($expected, $signature);
    }

    public function getRequestCount(): int
    {
        return $this->requestCount;
    }

    private function sendRequest(string $method, string $path, array $body = []): array
    {
        // HTTP client logic
        return [];
    }
}
