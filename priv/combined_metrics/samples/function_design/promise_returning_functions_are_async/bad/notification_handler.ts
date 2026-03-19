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

// Returns a Promise but is not marked async
function fetchNotification(id: string): Promise<Notification> {
  return fetch(`/api/notifications/${id}`)
    .then((response) => {
      if (!response.ok) throw new Error(`Notification not found: ${id}`);
      return response.json() as Promise<Notification>;
    });
}

// Returns a Promise but is not marked async
function sendNotification(notification: Notification): Promise<SendResult> {
  return fetch("/api/notifications/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: notification.id }),
  }).then((response) => {
    if (!response.ok) {
      return { notificationId: notification.id, success: false, error: `HTTP ${response.status}` };
    }
    return { notificationId: notification.id, success: true };
  });
}

// Returns a Promise but is not marked async
function fetchAndSend(notificationId: string): Promise<SendResult> {
  return fetchNotification(notificationId).then((notification) =>
    sendNotification(notification)
  );
}

// Returns a Promise but is not marked async
function sendBatch(notificationIds: string[]): Promise<SendResult[]> {
  return Promise.allSettled(
    notificationIds.map((id) => fetchAndSend(id))
  ).then((results) =>
    results.map((result, index) => {
      if (result.status === "fulfilled") return result.value;
      return {
        notificationId: notificationIds[index],
        success: false,
        error: result.reason instanceof Error ? result.reason.message : String(result.reason),
      };
    })
  );
}

export { fetchNotification, sendNotification, fetchAndSend, sendBatch };
export type { Notification, SendResult };
