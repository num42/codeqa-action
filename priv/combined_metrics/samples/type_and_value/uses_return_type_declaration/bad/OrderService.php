<?php

namespace App\Service;

use App\Entity\Order;
use App\Entity\LineItem;
use App\Exception\OrderNotFoundException;

class OrderService
{
    public function __construct(
        private $orders,
        private $inventory,
        private $payments
    ) {
    }

    // No return type declared — caller cannot know if null is possible
    public function findById(int $id)
    {
        return $this->orders->findById($id);
    }

    // No return type — is this an Order? array? null?
    public function createFromCart(int $customerId, array $cartItems)
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

    // No return type — returns bool but also throws
    public function cancel(int $orderId)
    {
        $order = $this->orders->findById($orderId);

        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        $order->setStatus('cancelled');
        $this->orders->save($order);

        return true;
    }

    // No return type — could be float, int, or null
    public function getTotalForCustomer(int $customerId)
    {
        $orders = $this->orders->findByCustomer($customerId, status: 'completed');

        return array_reduce($orders, fn($carry, $o) => $carry + $o->getTotal(), 0.0);
    }

    // No return type — could be string or throw
    public function getStatusLabel(int $orderId)
    {
        $order = $this->orders->findById($orderId);

        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        return match ($order->getStatus()) {
            'pending'   => 'Awaiting Confirmation',
            'confirmed' => 'Confirmed',
            default     => 'Unknown',
        };
    }

    // No return type — caller doesn't know it returns array
    public function listByStatus(int $status, int $limit = 20)
    {
        return $this->orders->findByStatus($status, $limit);
    }
}
