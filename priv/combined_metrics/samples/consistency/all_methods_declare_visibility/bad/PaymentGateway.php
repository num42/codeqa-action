<?php

namespace App\Payment;

class PaymentGateway
{
    private $apiKey;
    private $baseUrl;
    private $requestCount = 0;

    public function __construct($apiKey, $baseUrl)
    {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
    }

    // Missing visibility — defaults to public implicitly in PHP, but PSR-12 requires explicit declaration
    function charge($amountCents, $token)
    {
        $this->requestCount++;
        return $this->post('/v1/charges', ['amount' => $amountCents, 'source' => $token]);
    }

    // Missing visibility
    function refund($transactionId, $amountCents)
    {
        $this->requestCount++;
        return $this->post('/v1/refunds', ['transaction_id' => $transactionId, 'amount' => $amountCents]);
    }

    public function getRequestCount()
    {
        return $this->requestCount;
    }

    // Missing visibility on static method
    static function getTotalRequests()
    {
        return 0;
    }

    // Missing visibility
    function buildHeaders()
    {
        return [
            'Authorization' => "Bearer {$this->apiKey}",
            'Content-Type'  => 'application/json',
        ];
    }

    // Missing visibility on private method
    function post($path, $payload)
    {
        return [];
    }

    // Missing visibility
    function buildUrl($path)
    {
        return rtrim($this->baseUrl, '/') . $path;
    }

    // Missing visibility on abstract-style helper
    function validateAmount($amountCents)
    {
        if ($amountCents <= 0) {
            throw new \InvalidArgumentException("Amount must be positive");
        }
    }
}
