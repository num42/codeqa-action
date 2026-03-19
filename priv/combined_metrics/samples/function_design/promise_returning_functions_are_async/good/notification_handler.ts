interface Notification {
  id: string;
  userId: string;
  type: string;
  title: string;
  body: string;
  sentAt: string | null;
}

interface SendResult {
  notificationId: string;
  success: boolean;
  error?: string;
}

async function fetchNotification(id: string): Promise<Notification> {
  const response = await fetch(`/api/notifications/${id}`);
  if (!response.ok) throw new Error(`Notification not found: ${id}`);
  return response.json() as Promise<Notification>;
}

async function sendNotification(notification: Notification): Promise<SendResult> {
  const response = await fetch("/api/notifications/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: notification.id }),
  });

  if (!response.ok) {
    return { notificationId: notification.id, success: false, error: `HTTP ${response.status}` };
  }

  return { notificationId: notification.id, success: true };
}

async function fetchAndSend(notificationId: string): Promise<SendResult> {
  const notification = await fetchNotification(notificationId);
  return sendNotification(notification);
}

async function sendBatch(notificationIds: string[]): Promise<SendResult[]> {
  const results = await Promise.allSettled(
    notificationIds.map((id) => fetchAndSend(id))
  );

  return results.map((result, index) => {
    if (result.status === "fulfilled") return result.value;
    return {
      notificationId: notificationIds[index],
      success: false,
      error: result.reason instanceof Error ? result.reason.message : String(result.reason),
    };
  });
}

async function scheduleNotification(notification: Notification, delayMs: number): Promise<void> {
  await new Promise<void>((resolve) => setTimeout(resolve, delayMs));
  await sendNotification(notification);
}

export { fetchNotification, sendNotification, fetchAndSend, sendBatch, scheduleNotification };
export type { Notification, SendResult };
