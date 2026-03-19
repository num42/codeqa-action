<?php

declare(strict_types=1);

namespace App\Service;

use App\Entity\Order;
use App\Entity\LineItem;
use App\Exception\OrderNotFoundException;

// Class names use StudlyCaps (PascalCase) — PSR-1
class OrderService
{
    public function __construct(
        private OrderRepository $orderRepository,
        private LineItemRepository $lineItemRepository,
        private PaymentProcessor $paymentProcessor
    ) {
    }

    public function createOrder(int $customerId, array $items): Order
    {
        $order = new Order(customerId: $customerId);

        foreach ($items as $item) {
            $lineItem = new LineItem(
                productId: $item['product_id'],
                quantity: $item['quantity'],
                unitPrice: $item['unit_price']
            );
            $order->addLineItem($lineItem);
        }

        $this->orderRepository->save($order);

        return $order;
    }

    public function findById(int $id): ?Order
    {
        return $this->orderRepository->findById($id);
    }
}

// Additional classes in the namespace also follow StudlyCaps
class OrderSummaryBuilder
{
    public function build(Order $order): OrderSummary
    {
        return new OrderSummary(
            orderId: $order->getId(),
            total: $order->getTotal(),
            itemCount: $order->getLineItemCount(),
            status: $order->getStatus()
        );
    }
}

class OrderSummary
{
    public function __construct(
        public readonly int $orderId,
        public readonly float $total,
        public readonly int $itemCount,
        public readonly string $status
    ) {
    }
}
