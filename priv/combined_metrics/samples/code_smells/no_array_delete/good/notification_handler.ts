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
  return notifications.filter((n) => n.id !== id);
}

function removeNotificationsByType(
  notifications: Notification[],
  type: string
): Notification[] {
  return notifications.filter((n) => n.type !== type);
}

function removeReadNotifications(notifications: Notification[]): Notification[] {
  return notifications.filter((n) => n.readAt === null);
}

function removeAtIndex(notifications: Notification[], index: number): Notification[] {
  return [...notifications.slice(0, index), ...notifications.slice(index + 1)];
}

function clearBulk(notifications: Notification[], ids: Set<string>): Notification[] {
  return notifications.filter((n) => !ids.has(n.id));
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
    this.items = this.items.filter((n) => n.id !== id);
  }

  removeFirst(): Notification | undefined {
    return this.items.shift();
  }

  getAll(): Notification[] {
    return [...this.items];
  }

  get length(): number {
    return this.items.length;
  }
}

export { removeNotificationById, removeNotificationsByType, removeReadNotifications, removeAtIndex, clearBulk, NotificationQueue };
export type { Notification };
