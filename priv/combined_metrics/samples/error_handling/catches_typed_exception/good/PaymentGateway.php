<?php

declare(strict_types=1);

namespace App\Payment;

use App\Exception\CardDeclinedException;
use App\Exception\GatewayTimeoutException;
use App\Exception\InvalidCardException;
use Psr\Log\LoggerInterface;

class PaymentGateway
{
    public function __construct(
        private HttpClient $httpClient,
        private LoggerInterface $logger
    ) {
    }

    public function charge(int $amountCents, string $token, int $customerId): ChargeResult
    {
        try {
            $response = $this->httpClient->post('/v1/charges', [
                'amount'      => $amountCents,
                'source'      => $token,
                'customer_id' => $customerId,
            ]);

            return new ChargeResult(
                transactionId: $response['id'],
                status: $response['status']
            );
        } catch (CardDeclinedException $e) {
            $this->logger->info("Card declined for customer {$customerId}: {$e->getDeclineCode()}");
            throw $e;
        } catch (GatewayTimeoutException $e) {
            $this->logger->error("Gateway timeout for customer {$customerId}: {$e->getMessage()}");
            throw new \RuntimeException("Payment service temporarily unavailable", 0, $e);
        } catch (InvalidCardException $e) {
            $this->logger->warning("Invalid card for customer {$customerId}: {$e->getMessage()}");
            throw $e;
        }
    }

    public function refund(string $transactionId, int $amountCents): RefundResult
    {
        try {
            $response = $this->httpClient->post('/v1/refunds', [
                'transaction_id' => $transactionId,
                'amount'         => $amountCents,
            ]);

            return new RefundResult(refundId: $response['refund_id']);
        } catch (TransactionNotFoundException $e) {
            $this->logger->error("Refund failed — transaction not found: {$transactionId}");
            throw $e;
        } catch (RefundNotAllowedException $e) {
            $this->logger->warning("Refund not allowed for {$transactionId}: {$e->getMessage()}");
            throw $e;
        }
    }
}
