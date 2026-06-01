<?php

namespace App\Service;

class OrderService
{
    // Missing visibility on several properties — PSR-12 violation
    $orderRepository;          // no visibility modifier
    $paymentService;           // no visibility modifier
    $notificationService;      // no visibility modifier

    // Some have visibility, some don't — inconsistent
    protected string $defaultCurrency = 'USD';
    $auditEnabled = false;     // missing visibility

    static $instanceCount = 0; // missing visibility on static property
    const MAX_ITEMS_PER_ORDER = 50; // constants also lack visibility

    public function __construct($orderRepository, $paymentService, $notificationService)
    {
        $this->orderRepository = $orderRepository;
        $this->paymentService = $paymentService;
        $this->notificationService = $notificationService;
        self::$instanceCount++;
    }

    public function place($customerId, $items)
    {
        if (count($items) > self::MAX_ITEMS_PER_ORDER) {
            throw new \InvalidArgumentException('Too many items');
        }

        $order = new \stdClass();
        $order->customerId = $customerId;
        $order->currency = $this->defaultCurrency;
        $order->items = $items;

        $this->orderRepository->save($order);

        if ($this->auditEnabled) {
            $this->logPlacement($order);
        }

        return $order;
    }

    public function cancel($orderId)
    {
        $order = $this->orderRepository->findById($orderId);

        if ($order === null) {
            return false;
        }

        $order->status = 'cancelled';
        $this->orderRepository->save($order);

        return true;
    }

    static function getInstanceCount()  // missing visibility on static method
    {
        return self::$instanceCount;
    }

    function logPlacement($order): void  // missing visibility on instance method
    {
        // audit logging
    }
}
