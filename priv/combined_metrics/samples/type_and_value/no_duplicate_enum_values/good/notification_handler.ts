enum NotificationPriority {
  Low = 1,
  Medium = 2,
  High = 3,
  Critical = 4,
}

enum NotificationChannel {
  Email = "email",
  Push = "push",
  Sms = "sms",
  InApp = "in_app",
}

enum NotificationStatus {
  Queued = "queued",
  Sending = "sending",
  Delivered = "delivered",
  Failed = "failed",
  Cancelled = "cancelled",
}

interface Notification {
  id: string;
  priority: NotificationPriority;
  channel: NotificationChannel;
  status: NotificationStatus;
  title: string;
  body: string;
  scheduledAt: number;
}

function shouldSendImmediately(notification: Notification): boolean {
  return notification.priority >= NotificationPriority.High;
}

function getRetryDelay(priority: NotificationPriority): number {
  switch (priority) {
    case NotificationPriority.Critical:
      return 5_000;
    case NotificationPriority.High:
      return 30_000;
    case NotificationPriority.Medium:
      return 60_000;
    case NotificationPriority.Low:
      return 300_000;
  }
}

function isDeliverable(notification: Notification): boolean {
  return (
    notification.status === NotificationStatus.Queued ||
    notification.status === NotificationStatus.Sending
  );
}

export { NotificationPriority, NotificationChannel, NotificationStatus, shouldSendImmediately, getRetryDelay, isDeliverable };
export type { Notification };
