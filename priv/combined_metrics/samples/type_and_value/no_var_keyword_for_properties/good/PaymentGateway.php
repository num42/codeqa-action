<?php

declare(strict_types=1);

namespace App\Payment;

class PaymentGateway
{
    private string $apiKey;
    private string $baseUrl;
    private int $timeoutMs;
    protected string $currency;
    public bool $sandboxMode;

    private static int $requestCount = 0;
    private const string DEFAULT_CURRENCY = 'USD';

    public function __construct(
        string $apiKey,
        string $baseUrl,
        int $timeoutMs = 5000,
        bool $sandboxMode = false
    ) {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
        $this->timeoutMs = $timeoutMs;
        $this->sandboxMode = $sandboxMode;
        $this->currency = self::DEFAULT_CURRENCY;
    }

    public function charge(int $amountCents, string $token): ChargeResult
    {
        self::$requestCount++;

        $payload = [
            'amount'   => $amountCents,
            'currency' => $this->currency,
            'source'   => $token,
        ];

        return $this->post('/v1/charges', $payload);
    }

    public function setCurrency(string $currency): void
    {
        $this->currency = strtoupper($currency);
    }

    public static function getRequestCount(): int
    {
        return self::$requestCount;
    }

    private function post(string $path, array $payload): ChargeResult
    {
        // HTTP client logic
        return new ChargeResult(transactionId: uniqid('txn_'));
    }
}
