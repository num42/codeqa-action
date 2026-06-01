<?php

declare(strict_types=1);

namespace App\Payment;

// All methods explicitly declare visibility — PSR-12
class PaymentGateway
{
    private string $apiKey;
    private string $baseUrl;
    private int $requestCount = 0;
    private static int $totalRequests = 0;

    public function __construct(string $apiKey, string $baseUrl)
    {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
    }

    public function charge(int $amountCents, string $token): array
    {
        $this->requestCount++;
        self::$totalRequests++;

        return $this->post('/v1/charges', ['amount' => $amountCents, 'source' => $token]);
    }

    public function refund(string $transactionId, int $amountCents): array
    {
        $this->requestCount++;
        self::$totalRequests++;

        return $this->post('/v1/refunds', ['transaction_id' => $transactionId, 'amount' => $amountCents]);
    }

    public function getRequestCount(): int
    {
        return $this->requestCount;
    }

    public static function getTotalRequests(): int
    {
        return self::$totalRequests;
    }

    protected function buildHeaders(): array
    {
        return [
            'Authorization' => "Bearer {$this->apiKey}",
            'Content-Type'  => 'application/json',
        ];
    }

    private function post(string $path, array $payload): array
    {
        $url = $this->buildUrl($path);
        // HTTP client logic
        return [];
    }

    private function buildUrl(string $path): string
    {
        return rtrim($this->baseUrl, '/') . $path;
    }

    private function validateAmount(int $amountCents): void
    {
        if ($amountCents <= 0) {
            throw new \InvalidArgumentException("Amount must be positive: {$amountCents}");
        }
    }
}
