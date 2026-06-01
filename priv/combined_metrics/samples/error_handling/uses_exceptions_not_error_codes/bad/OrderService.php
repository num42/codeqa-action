<?php

namespace App\Service;

class OrderService
{
    public function __construct(
        private $orders,
        private $inventory,
        private $payments
    ) {
    }

    // Returns error codes / false instead of throwing exceptions
    public function place($customerId, $items)
    {
        foreach ($items as $item) {
            $available = $this->inventory->getAvailableQuantity($item['product_id']);
            if ($available < $item['quantity']) {
                return -1; // Caller must know magic codes
            }
        }

        $order = new \stdClass();
        $order->customerId = $customerId;
        $order->status = 'pending';
        $order->items = $items;
        $saved = $this->orders->save($order);

        if (!$saved) {
            return false; // Is false a different error than -1?
        }

        return $order;
    }

    public function confirm($orderId, $paymentToken)
    {
        $order = $this->orders->findById($orderId);
        if ($order === null) {
            return null; // Caller must null-check
        }

        if ($order->status !== 'pending') {
            return -2; // Magic number for wrong state
        }

        $charged = $this->payments->charge($order->total, $paymentToken);
        if (!$charged) {
            return -3; // Magic number for payment failed
        }

        $order->status = 'confirmed';
        $this->orders->save($order);

        return $order;
    }

    public function getOrFail($orderId)
    {
        $order = $this->orders->findById($orderId);

        // Returns false — caller must remember to check === false
        return $order ?? false;
    }
}
