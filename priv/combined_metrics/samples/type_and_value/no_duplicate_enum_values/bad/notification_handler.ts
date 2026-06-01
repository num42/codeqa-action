enum NotificationPriority {
  Low = 1,
  Medium = 2,
  Normal = 2,   // Duplicate of Medium
  High = 3,
  Urgent = 3,   // Duplicate of High
  Critical = 4,
}

enum NotificationChannel {
  Email = "email",
  EmailDigest = "email",  // Duplicate of Email
  Push = "push",
  MobilePush = "push",    // Duplicate of Push
  Sms = "sms",
  InApp = "in_app",
}

enum NotificationStatus {
  Queued = "queued",
  Pending = "queued",     // Duplicate of Queued
  Sending = "sending",
  InFlight = "sending",   // Duplicate of Sending
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

function isDeliverable(notification: Notification): boolean {
  return (
    notification.status === NotificationStatus.Queued ||
    notification.status === NotificationStatus.Sending
  );
}

export { NotificationPriority, NotificationChannel, NotificationStatus, shouldSendImmediately, isDeliverable };
export type { Notification };
