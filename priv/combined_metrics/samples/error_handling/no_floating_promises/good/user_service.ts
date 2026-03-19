import logger from "./logger.js";

interface User {
  id: string;
  email: string;
  displayName: string;
}

interface AuditEntry {
  action: string;
  userId: string;
  timestamp: number;
}

async function fetchUser(userId: string): Promise<User> {
  const response = await fetch(`/api/users/${userId}`);
  if (!response.ok) throw new Error(`User not found: ${userId}`);
  return response.json() as Promise<User>;
}

async function writeAuditLog(entry: AuditEntry): Promise<void> {
  await fetch("/api/audit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(entry),
  });
}

async function deleteUser(userId: string): Promise<void> {
  const user = await fetchUser(userId);

  const response = await fetch(`/api/users/${userId}`, { method: "DELETE" });
  if (!response.ok) throw new Error(`Failed to delete user: ${response.status}`);

  await writeAuditLog({
    action: "user_deleted",
    userId: user.id,
    timestamp: Date.now(),
  });
}

async function updateEmail(userId: string, newEmail: string): Promise<User> {
  const response = await fetch(`/api/users/${userId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: newEmail }),
  });

  if (!response.ok) throw new Error(`Failed to update email: ${response.status}`);

  const updated: User = await response.json();

  await writeAuditLog({
    action: "email_updated",
    userId,
    timestamp: Date.now(),
  });

  return updated;
}

async function bulkInviteUsers(emails: string[]): Promise<{ sent: number; failed: number }> {
  const results = await Promise.allSettled(
    emails.map((email) =>
      fetch("/api/invitations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      })
    )
  );

  const sent = results.filter((r) => r.status === "fulfilled").length;
  const failed = results.filter((r) => r.status === "rejected").length;

  for (const r of results) {
    if (r.status === "rejected") {
      logger.error("Invitation failed", r.reason);
    }
  }

  return { sent, failed };
}

export { fetchUser, deleteUser, updateEmail, bulkInviteUsers };
export type { User };
