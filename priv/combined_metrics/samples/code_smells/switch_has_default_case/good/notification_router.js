import logger from "./logger.js";

function getNotificationChannel(userPreferences, notificationType) {
  switch (notificationType) {
    case "order_confirmed":
      return userPreferences.emailEnabled ? "email" : "push";
    case "order_shipped":
      return "push";
    case "order_delivered":
      return userPreferences.emailEnabled ? "email" : "push";
    case "payment_failed":
      return "email";
    case "account_locked":
      return "email";
    case "promotional":
      return userPreferences.marketingEnabled ? "email" : null;
    default:
      logger.warn(`Unknown notification type: '${notificationType}'`);
      return null;
  }
}

function formatNotificationMessage(notification) {
  const { type, data } = notification;

  switch (type) {
    case "order_confirmed":
      return {
        subject: `Order #${data.orderId} confirmed`,
        body: `Your order has been confirmed and is being prepared.`,
      };
    case "order_shipped":
      return {
        subject: `Order #${data.orderId} is on its way`,
        body: `Your order has shipped. Tracking number: ${data.trackingNumber}`,
      };
    case "order_delivered":
      return {
        subject: `Order #${data.orderId} delivered`,
        body: `Your order has been delivered. Enjoy!`,
      };
    case "payment_failed":
      return {
        subject: "Payment failed",
        body: `Your payment of ${data.amount} could not be processed.`,
      };
    default:
      throw new Error(`No message template for notification type: '${type}'`);
  }
}

export { getNotificationChannel, formatNotificationMessage };
