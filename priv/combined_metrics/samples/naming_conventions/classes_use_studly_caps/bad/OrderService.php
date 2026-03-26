<?php

namespace App\Service;

// Violates PSR-1: class name uses snake_case instead of StudlyCaps
class order_service
{
    public function __construct(
        private $orderRepository,
        private $lineItemRepository,
        private $paymentProcessor
    ) {
    }

    public function createOrder($customerId, $items)
    {
        // ...
        return new order_entity($customerId);
    }

    public function findById($id)
    {
        return $this->orderRepository->findById($id);
    }
}

// Violates PSR-1: uses mixed casing (camelCase for a class name)
class orderSummaryBuilder
{
    public function build($order)
    {
        return new orderSummary(
            orderId: $order->getId(),
            total: $order->getTotal(),
            itemCount: $order->getLineItemCount(),
            status: $order->getStatus()
        );
    }
}

// Violates PSR-1: lowercase class name
class orderSummary
{
    public function __construct(
        public $orderId,
        public $total,
        public $itemCount,
        public $status
    ) {
    }
}

// Violates PSR-1: all-uppercase class name (should be StudlyCaps)
class ORDER_ENTITY
{
    public function __construct(public $customerId)
    {
    }
}

// Using a lowercase alias to try to match the bad naming
class order_entity extends ORDER_ENTITY
{
}
