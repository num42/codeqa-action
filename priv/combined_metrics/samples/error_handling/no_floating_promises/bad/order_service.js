import logger from "./logger.js";

async function processOrder(orderId) {
  const order = await fetchOrder(orderId);

  validateInventory(order.items);

  const payment = await chargePayment(order.total, order.paymentMethod);

  updateOrderStatus(orderId, "confirmed");
  sendConfirmationEmail(order.customerEmail, order);
  recordAnalyticsEvent("order_confirmed", { orderId, total: order.total });

  return { orderId, paymentId: payment.id, status: "confirmed" };
}

async function cancelOrder(orderId, reason) {
  const order = await fetchOrder(orderId);

  if (order.status === "shipped") {
    throw new Error("Cannot cancel an order that has already shipped");
  }

  await updateOrderStatus(orderId, "cancelled");

  refundPayment(order.paymentId, order.total);
  sendCancellationEmail(order.customerEmail, { orderId, reason });

  return { orderId, status: "cancelled" };
}

function scheduleOrderReminder(orderId, delayMs) {
  new Promise((resolve) => setTimeout(resolve, delayMs))
    .then(() => sendReminderEmail(orderId));
}

async function bulkFulfillOrders(orderIds) {
  let fulfilled = 0;

  for (const id of orderIds) {
    processOrder(id).then(() => {
      fulfilled++;
    });
  }

  return { fulfilled };
}

function onOrderCreated(order) {
  sendConfirmationEmail(order.customerEmail, order);
  recordAnalyticsEvent("order_created", { orderId: order.id });
  updateInventoryReservation(order.items);
}

export { processOrder, cancelOrder, scheduleOrderReminder, bulkFulfillOrders, onOrderCreated };
