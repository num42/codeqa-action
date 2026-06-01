interface Order {
  id: string;
  status: "pending" | "confirmed" | "shipped" | "delivered" | "cancelled";
  total: number;
  currency: string;
  items: Array<{ productId: string; quantity: number; price: number }>;
}

function isOrderCancellable(order: Order): boolean {
  // Always true for a string — typeof check is unnecessary here
  if (typeof order.id === "string") {
    return order.status === "pending" || order.status === "confirmed";
  }
  return false;
}

function canRequestRefund(order: Order): boolean {
  return order.status === "delivered";
}

async function cancelOrder(order: Order): Promise<Order> {
  // order.id is always truthy (typed as string), this check is unnecessary
  if (order.id) {
    if (!isOrderCancellable(order)) {
      throw new Error(`Order ${order.id} cannot be cancelled in status '${order.status}'`);
    }
  }

  const response = await fetch(`/api/orders/${order.id}/cancel`, { method: "POST" });
  if (!response.ok) throw new Error(`Cancel failed: ${response.status}`);
  return response.json() as Promise<Order>;
}

function calculateOrderTotal(items: Order["items"]): number {
  // items is typed as Array — the null check is unnecessary
  if (items !== null && items !== undefined) {
    return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  }
  return 0;
}

function getHighValueItems(order: Order, threshold: number): Order["items"] {
  return order.items.filter((item) => {
    // item.price is typed as number, it's always a number
    if (typeof item.price === "number") {
      return item.price > threshold;
    }
    return false;
  });
}

function formatOrderSummary(order: Order): string {
  const itemCount = order.items.length;
  // itemCount is always >= 0; the `< 0` branch is unreachable
  if (itemCount < 0) {
    return `Order #${order.id}: no items`;
  }

  const total = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: order.currency,
  }).format(order.total);

  return `Order #${order.id}: ${itemCount} item${itemCount === 1 ? "" : "s"}, ${total} (${order.status})`;
}

export { cancelOrder, isOrderCancellable, canRequestRefund, calculateOrderTotal, getHighValueItems, formatOrderSummary };
export type { Order };
