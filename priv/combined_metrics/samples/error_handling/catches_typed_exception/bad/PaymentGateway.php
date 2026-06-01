<?php

namespace App\Payment;

class PaymentGateway
{
    public function __construct(
        private $httpClient,
        private $logger
    ) {
    }

    public function charge($amountCents, $token, $customerId)
    {
        try {
            $response = $this->httpClient->post('/v1/charges', [
                'amount'      => $amountCents,
                'source'      => $token,
                'customer_id' => $customerId,
            ]);

            return [
                'transaction_id' => $response['id'],
                'status'         => $response['status'],
            ];
        } catch (\Exception $e) {
            // Bare \Exception catches everything — loses all error specificity
            $this->logger->error("Charge failed: {$e->getMessage()}");
            return null;
        }
    }

    public function refund($transactionId, $amountCents)
    {
        try {
            $response = $this->httpClient->post('/v1/refunds', [
                'transaction_id' => $transactionId,
                'amount'         => $amountCents,
            ]);

            return ['refund_id' => $response['refund_id']];
        } catch (\Throwable $e) {
            // \Throwable is even broader — catches Errors and Exceptions alike
            $this->logger->error("Refund failed: {$e->getMessage()}");
            return false;
        }
    }

    public function validateCard($cardNumber, $expiry, $cvv)
    {
        try {
            return $this->httpClient->post('/v1/validate', [
                'number' => $cardNumber,
                'expiry' => $expiry,
                'cvv'    => $cvv,
            ]);
        } catch (\Exception $e) {
            // Swallows all exceptions — caller gets null regardless of cause
            return null;
        }
    }
}
