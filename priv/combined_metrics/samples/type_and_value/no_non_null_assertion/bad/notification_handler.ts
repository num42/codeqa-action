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
  // Non-null assertion instead of explicit check
  const notification = store.get(notificationId)!;
  return { ...notification, readAt: new Date().toISOString() };
}

function getActionUrl(notification: Notification): string {
  // Non-null assertion on a nullable field
  return notification.actionUrl!;
}

function getLatestUnread(notifications: Notification[]): Notification {
  const unread = notifications.filter((n) => n.readAt === null);
  // Non-null assertion assuming there is always at least one unread
  return unread[0]!;
}

function getFirstNotification(store: NotificationStore, userId: string): Notification {
  const all = store.getAll(userId);
  return all[0]!;
}

function renderNotificationBadge(notifications: Notification[]): string {
  const count = notifications.filter((n) => n.readAt === null).length;
  if (count === 0) return "";
  if (count > 99) return "99+";
  return String(count);
}

function getNotificationTitle(store: NotificationStore, id: string): string {
  return store.get(id)!.title;
}

export {
  markAsRead,
  getActionUrl,
  getLatestUnread,
  getFirstNotification,
  renderNotificationBadge,
  getNotificationTitle,
};
export type { Notification, NotificationStore };
