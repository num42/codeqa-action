interface Notification {
  id: string;
  userId: string;
  type: string;
  title: string;
  body: string;
  readAt: string | null;
  actionUrl: string | null;
}

interface NotificationStore {
  get(id: string): Notification | undefined;
  getAll(userId: string): Notification[];
}

function markAsRead(store: NotificationStore, notificationId: string): Notification {
  const notification = store.get(notificationId);

  if (notification === undefined) {
    throw new Error(`Notification not found: ${notificationId}`);
  }

  return { ...notification, readAt: new Date().toISOString() };
}

function getActionUrl(notification: Notification): string {
  if (notification.actionUrl === null) {
    return "/notifications";
  }
  return notification.actionUrl;
}

function countUnread(notifications: Notification[]): number {
  return notifications.filter((n) => n.readAt === null).length;
}

function getLatestUnread(notifications: Notification[]): Notification | null {
  const unread = notifications.filter((n) => n.readAt === null);
  if (unread.length === 0) return null;
  return unread.reduce((latest, n) =>
    n.id > latest.id ? n : latest
  );
}

function renderNotificationBadge(notifications: Notification[]): string {
  const count = countUnread(notifications);
  if (count === 0) return "";
  if (count > 99) return "99+";
  return String(count);
}

function groupByType(notifications: Notification[]): Map<string, Notification[]> {
  return notifications.reduce((groups, notification) => {
    const existing = groups.get(notification.type) ?? [];
    groups.set(notification.type, [...existing, notification]);
    return groups;
  }, new Map<string, Notification[]>());
}

export { markAsRead, getActionUrl, countUnread, getLatestUnread, renderNotificationBadge, groupByType };
export type { Notification, NotificationStore };
