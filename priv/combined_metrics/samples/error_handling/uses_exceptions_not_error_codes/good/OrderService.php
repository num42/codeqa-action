<?php

declare(strict_types=1);

namespace App\Service;

use App\Entity\Order;
use App\Exception\OrderNotFoundException;
use App\Exception\InvalidOrderStateException;
use App\Exception\PaymentFailedException;
use App\Exception\InsufficientStockException;

class OrderService
{
    public function __construct(
        private OrderRepository $orders,
        private InventoryService $inventory,
        private PaymentService $payments
    ) {
    }

    public function place(int $customerId, array $items): Order
    {
        foreach ($items as $item) {
            $available = $this->inventory->getAvailableQuantity($item['product_id']);
            if ($available < $item['quantity']) {
                throw new InsufficientStockException(
                    "Product {$item['product_id']} has only {$available} units available"
                );
            }
        }

        $order = new Order(customerId: $customerId, status: 'pending');
        foreach ($items as $item) {
            $order->addItem($item['product_id'], $item['quantity'], $item['unit_price']);
        }
        $this->orders->save($order);

        return $order;
    }

    public function confirm(int $orderId, string $paymentToken): Order
    {
        $order = $this->orders->findById($orderId);
        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        if ($order->getStatus() !== 'pending') {
            throw new InvalidOrderStateException(
                "Cannot confirm order in state '{$order->getStatus()}'"
            );
        }

        $this->payments->charge($order->getTotal(), $paymentToken);

        $order->setStatus('confirmed');
        $this->orders->save($order);

        return $order;
    }

    public function getOrFail(int $orderId): Order
    {
        $order = $this->orders->findById($orderId);
        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        return $order;
    }
}
