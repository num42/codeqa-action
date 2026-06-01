<?php

namespace App\Service;

class OrderService
{
    public function getStatusLabel($status): string
    {
        switch ($status) {
            case 'pending':
                return 'Awaiting Confirmation';
            case 'confirmed':
                return 'Confirmed';
            case 'processing':
                return 'Being Prepared';
            case 'shipped':
                return 'On the Way';
            case 'delivered':
                // Falls through to 'completed' with no comment — PSR-12 violation
            case 'completed':
                return 'Delivered';
            case 'cancelled':
                return 'Cancelled';
            default:
                return 'Unknown';
        }
    }

    public function getStatusPriority($status): int
    {
        switch ($status) {
            case 'pending':
                $priority = 10;
                break;
            case 'confirmed':
                // Intentional fall-through but missing the required `// no break` comment
            case 'processing':
                $priority = 20;
                break;
            case 'shipped':
                $priority = 30;
                break;
            case 'delivered':
                // Missing fall-through comment
            case 'completed':
                $priority = 0;
                break;
            default:
                $priority = -1;
                break;
        }

        return $priority;
    }

    public function applyDiscount($status, &$total): void
    {
        switch ($status) {
            case 'vip':
                $total *= 0.8;
                // Falls through without comment — ambiguous: bug or intent?
            case 'member':
                $total *= 0.95;
                break;
            case 'guest':
                break;
            default:
                break;
        }
    }
}
