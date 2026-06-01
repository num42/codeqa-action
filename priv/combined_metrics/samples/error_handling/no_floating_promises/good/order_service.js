import logger from "./logger.js";

async function processOrder(orderId) {
  const order = await fetchOrder(orderId);

  await validateInventory(order.items);

  const payment = await chargePayment(order.total, order.paymentMethod);

  await Promise.all([
    updateOrderStatus(orderId, "confirmed"),
    sendConfirmationEmail(order.customerEmail, order),
    recordAnalyticsEvent("order_confirmed", { orderId, total: order.total }),
  ]);

  return { orderId, paymentId: payment.id, status: "confirmed" };
}

async function cancelOrder(orderId, reason) {
  const order = await fetchOrder(orderId);

  if (order.status === "shipped") {
    throw new Error("Cannot cancel an order that has already shipped");
  }

  await updateOrderStatus(orderId, "cancelled");

  const refundPromise = refundPayment(order.paymentId, order.total);
  const emailPromise = sendCancellationEmail(order.customerEmail, { orderId, reason });

  const [refund] = await Promise.all([refundPromise, emailPromise]);

  return { orderId, refundId: refund.id, status: "cancelled" };
}

function scheduleOrderReminder(orderId, delayMs) {
  const reminderPromise = new Promise((resolve) => setTimeout(resolve, delayMs))
    .then(() => sendReminderEmail(orderId))
    .catch((err) => logger.error("Reminder email failed", { orderId, err }));

  return reminderPromise;
}

async function bulkFulfillOrders(orderIds) {
  const results = await Promise.allSettled(
    orderIds.map((id) => processOrder(id))
  );

  const fulfilled = results.filter((r) => r.status === "fulfilled").length;
  const failed = results.filter((r) => r.status === "rejected");

  for (const result of failed) {
    logger.error("Order fulfillment failed", result.reason);
  }

  return { fulfilled, failedCount: failed.length };
}

export { processOrder, cancelOrder, scheduleOrderReminder, bulkFulfillOrders };
