<?php

declare(strict_types=1);

namespace App\Service;

use App\Entity\Order;
use App\Entity\LineItem;
use App\Exception\OrderNotFoundException;
use App\Exception\InvalidOrderStateException;

class OrderService
{
    public function __construct(
        private OrderRepository $orders,
        private InventoryService $inventory,
        private PaymentService $payments
    ) {
    }

    public function findById(int $id): ?Order
    {
        return $this->orders->findById($id);
    }

    public function createFromCart(int $customerId, array $cartItems): Order
    {
        $order = new Order(customerId: $customerId, status: 'pending');

        foreach ($cartItems as $item) {
            $order->addLineItem(new LineItem(
                productId: $item['product_id'],
                quantity: $item['quantity'],
                unitPrice: $item['unit_price']
            ));
        }

        $this->orders->save($order);

        return $order;
    }

    public function cancel(int $orderId): bool
    {
        $order = $this->orders->findById($orderId);

        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        if (!in_array($order->getStatus(), ['pending', 'confirmed'], true)) {
            throw new InvalidOrderStateException("Cannot cancel order in state: {$order->getStatus()}");
        }

        $order->setStatus('cancelled');
        $this->orders->save($order);
        $this->inventory->releaseReservations($orderId);

        return true;
    }

    public function getTotalForCustomer(int $customerId): float
    {
        $orders = $this->orders->findByCustomer($customerId, status: 'completed');

        return array_reduce($orders, fn(float $carry, Order $o) => $carry + $o->getTotal(), 0.0);
    }

    public function getStatusLabel(int $orderId): string
    {
        $order = $this->orders->findById($orderId);

        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        return match ($order->getStatus()) {
            'pending'   => 'Awaiting Confirmation',
            'confirmed' => 'Confirmed',
            'shipped'   => 'Shipped',
            'completed' => 'Delivered',
            'cancelled' => 'Cancelled',
            default     => 'Unknown',
        };
    }

    public function listByStatus(string $status, int $limit = 20): array
    {
        return $this->orders->findByStatus($status, $limit);
    }
}
