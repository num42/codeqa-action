<?php

declare(strict_types=1);

namespace App\Service;

class OrderService
{
    public function getStatusLabel(string $status): string
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
                // no break
            case 'completed':
                // Both 'delivered' and 'completed' map to the same label.
                // Intentional fall-through marked with `// no break`.
                return 'Delivered';
            case 'cancelled':
                return 'Cancelled';
            default:
                return 'Unknown';
        }
    }

    public function getStatusPriority(string $status): int
    {
        switch ($status) {
            case 'pending':
                $priority = 10;
                break;
            case 'confirmed':
                // no break
            case 'processing':
                // Both 'confirmed' and 'processing' have the same urgency level.
                // Intentional fall-through.
                $priority = 20;
                break;
            case 'shipped':
                $priority = 30;
                break;
            case 'delivered':
                // no break
            case 'completed':
                // Intentional fall-through — both statuses are terminal.
                $priority = 0;
                break;
            default:
                $priority = -1;
                break;
        }

        return $priority;
    }

    public function canTransitionTo(string $current, string $next): bool
    {
        switch ($current) {
            case 'pending':
                return in_array($next, ['confirmed', 'cancelled'], true);
            case 'confirmed':
                return in_array($next, ['processing', 'cancelled'], true);
            case 'processing':
                return $next === 'shipped';
            case 'shipped':
                return in_array($next, ['delivered', 'completed'], true);
            default:
                return false;
        }
    }
}
