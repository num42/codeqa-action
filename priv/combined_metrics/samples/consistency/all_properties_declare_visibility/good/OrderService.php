<?php

declare(strict_types=1);

namespace App\Service;

use App\Entity\Order;
use App\Exception\OrderNotFoundException;

class OrderService
{
    // All properties explicitly declare visibility
    private OrderRepository $orderRepository;
    private PaymentService $paymentService;
    private NotificationService $notificationService;
    protected string $defaultCurrency = 'USD';
    public bool $auditEnabled = false;

    private static int $instanceCount = 0;
    private const int MAX_ITEMS_PER_ORDER = 50;

    public function __construct(
        OrderRepository $orderRepository,
        PaymentService $paymentService,
        NotificationService $notificationService
    ) {
        $this->orderRepository = $orderRepository;
        $this->paymentService = $paymentService;
        $this->notificationService = $notificationService;
        self::$instanceCount++;
    }

    public function place(int $customerId, array $items): Order
    {
        if (count($items) > self::MAX_ITEMS_PER_ORDER) {
            throw new \InvalidArgumentException(
                'Order exceeds maximum of ' . self::MAX_ITEMS_PER_ORDER . ' items'
            );
        }

        $order = new Order(customerId: $customerId, currency: $this->defaultCurrency);
        foreach ($items as $item) {
            $order->addItem($item['product_id'], $item['quantity'], $item['unit_price']);
        }

        $this->orderRepository->save($order);

        if ($this->auditEnabled) {
            $this->logPlacement($order);
        }

        return $order;
    }

    public function cancel(int $orderId): bool
    {
        $order = $this->orderRepository->findById($orderId);

        if ($order === null) {
            throw new OrderNotFoundException("Order {$orderId} not found");
        }

        $order->setStatus('cancelled');
        $this->orderRepository->save($order);
        $this->notificationService->notifyCancellation($order);

        return true;
    }

    public static function getInstanceCount(): int
    {
        return self::$instanceCount;
    }

    private function logPlacement(Order $order): void
    {
        // audit logging
    }
}
