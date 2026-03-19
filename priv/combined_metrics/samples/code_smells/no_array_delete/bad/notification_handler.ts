interface Notification {
  id: string;
  userId: string;
  type: string;
  title: string;
  readAt: string | null;
}

function removeNotificationById(
  notifications: Notification[],
  id: string
): Notification[] {
  const index = notifications.findIndex((n) => n.id === id);
  if (index !== -1) {
    // delete leaves a hole (undefined) in the array instead of removing the element
    delete notifications[index];
  }
  return notifications;
}

function removeReadNotifications(notifications: Notification[]): Notification[] {
  for (let i = 0; i < notifications.length; i++) {
    if (notifications[i].readAt !== null) {
      delete notifications[i];
    }
  }
  return notifications;
}

function clearBulk(notifications: Notification[], ids: Set<string>): Notification[] {
  for (let i = 0; i < notifications.length; i++) {
    if (ids.has(notifications[i].id)) {
      delete notifications[i];
    }
  }
  return notifications;
}

class NotificationQueue {
  private items: Notification[];

  constructor(initial: Notification[] = []) {
    this.items = [...initial];
  }

  enqueue(notification: Notification): void {
    this.items.push(notification);
  }

  remove(id: string): void {
    const index = this.items.findIndex((n) => n.id === id);
    if (index !== -1) {
      delete this.items[index];
    }
  }

  getAll(): Notification[] {
    return [...this.items];
  }

  get length(): number {
    return this.items.length;
  }
}

export { removeNotificationById, removeReadNotifications, clearBulk, NotificationQueue };
export type { Notification };
