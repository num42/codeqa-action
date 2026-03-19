interface Order {
  id: string;
  status: "pending" | "confirmed" | "shipped" | "delivered" | "cancelled";
  total: number;
  currency: string;
  items: Array<{ productId: string; quantity: number; price: number }>;
}

function isOrderCancellable(order: Order): boolean {
  return order.status === "pending" || order.status === "confirmed";
}

function canRequestRefund(order: Order): boolean {
  return order.status === "delivered";
}

async function cancelOrder(order: Order): Promise<Order> {
  if (!isOrderCancellable(order)) {
    throw new Error(`Order ${order.id} cannot be cancelled in status '${order.status}'`);
  }

  const response = await fetch(`/api/orders/${order.id}/cancel`, { method: "POST" });
  if (!response.ok) throw new Error(`Cancel failed: ${response.status}`);
  return response.json() as Promise<Order>;
}

function calculateOrderTotal(items: Order["items"]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

function getHighValueItems(order: Order, threshold: number): Order["items"] {
  return order.items.filter((item) => item.price > threshold);
}

function formatOrderSummary(order: Order): string {
  const itemCount = order.items.length;
  const total = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: order.currency,
  }).format(order.total);

  return `Order #${order.id}: ${itemCount} item${itemCount === 1 ? "" : "s"}, ${total} (${order.status})`;
}

export { cancelOrder, isOrderCancellable, canRequestRefund, calculateOrderTotal, getHighValueItems, formatOrderSummary };
export type { Order };
