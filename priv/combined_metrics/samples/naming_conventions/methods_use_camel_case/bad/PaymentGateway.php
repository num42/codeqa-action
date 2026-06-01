<?php

namespace App\Payment;

class PaymentGateway
{
    private string $apiKey;
    private string $baseUrl;
    private int $request_count = 0;

    public function __construct(string $apiKey, string $baseUrl)
    {
        $this->apiKey = $apiKey;
        $this->baseUrl = $baseUrl;
    }

    // Violates PSR-1: method uses snake_case instead of camelCase
    public function charge_card($amountCents, $token)
    {
        $this->request_count++;
        $response = $this->send_request('POST', '/v1/charges', [
            'amount' => $amountCents,
            'source' => $token,
        ]);

        return ['transaction_id' => $response['id']];
    }

    // Violates PSR-1: snake_case method name
    public function issue_refund($transactionId, $amountCents)
    {
        $response = $this->send_request('POST', '/v1/refunds', [
            'transaction_id' => $transactionId,
            'amount'         => $amountCents,
        ]);

        return ['refund_id' => $response['refund_id']];
    }

    // Violates PSR-1: snake_case method name
    public function get_transaction_status($transactionId)
    {
        $response = $this->send_request('GET', "/v1/charges/{$transactionId}");

        return $response['status'];
    }

    // Violates PSR-1: snake_case method name
    public function validate_webhook_signature($payload, $signature)
    {
        $expected = hash_hmac('sha256', $payload, $this->apiKey);

        return hash_equals($expected, $signature);
    }

    // Violates PSR-1: snake_case method name
    public function get_request_count()
    {
        return $this->request_count;
    }

    // Violates PSR-1: snake_case private method name
    private function send_request($method, $path, $body = [])
    {
        return [];
    }
}
