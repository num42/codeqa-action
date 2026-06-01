<?php

declare(strict_types=1);

namespace App\Service;

use App\Entity\Order;
use App\Exception\OrderNotFoundException;

class OrderService
{
    private array $orders = [];

    public function __construct(private OrderRepository $repository)
    {
    }

    public function findById(int $id): ?Order
    {
        if (isset($this->orders[$id])) {
            return $this->orders[$id];
        }

        $order = $this->repository->findById($id);
        if ($order !== null) {
            $this->orders[$id] = $order;
        }

        return $order;
    }

    public function getStatus(int $orderId): string
    {
        $order = $this->findById($orderId);
        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        return $order->getStatus();
    }

    public function updateStatus(int $orderId, string $status): void
    {
        $order = $this->findById($orderId);
        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        $order->setStatus($status);
        $this->repository->save($order);
        unset($this->orders[$orderId]);
    }

    public function listByCustomer(int $customerId): array
    {
        return $this->repository->findByCustomer($customerId);
    }

    public function countByStatus(string $status): int
    {
        return $this->repository->countByStatus($status);
    }
}
