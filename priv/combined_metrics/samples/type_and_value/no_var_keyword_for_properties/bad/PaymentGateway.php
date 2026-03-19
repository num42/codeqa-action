<?php

namespace App\Payment;

class PaymentGateway
{
    // `var` is a PHP 4 remnant — it implies public visibility and is forbidden by PSR-12
    var $apiKey;
    var $baseUrl;
    var $timeoutMs;
    var $currency;
    var $sandboxMode;

    var $requestCount = 0;

    public function __construct(
        $apiKey,
        $baseUrl,
        $timeoutMs = 5000,
        $sandboxMode = false
    ) {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
        $this->timeoutMs = $timeoutMs;
        $this->sandboxMode = $sandboxMode;
        $this->currency = 'USD';
    }

    public function charge($amountCents, $token)
    {
        $this->requestCount++;

        $payload = [
            'amount'   => $amountCents,
            'currency' => $this->currency,
            'source'   => $token,
        ];

        return $this->post('/v1/charges', $payload);
    }

    public function setCurrency($currency)
    {
        $this->currency = strtoupper($currency);
    }

    public function getRequestCount()
    {
        return $this->requestCount;
    }

    private function post($path, $payload)
    {
        return ['transaction_id' => uniqid('txn_')];
    }
}
