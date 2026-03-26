async function fetchUser(userId: string): Promise<any> {
  const response = await fetch(`/api/users/${userId}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch user ${userId}: ${response.status}`);
  }

  return response.json();
}

async function createUser(payload: any): Promise<any> {
  const response = await fetch("/api/users", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error: any = await response.json();
    throw new Error(error.message);
  }

  return response.json();
}

async function updateUser(userId: string, changes: any): Promise<any> {
  const response = await fetch(`/api/users/${userId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(changes),
  });

  if (!response.ok) {
    throw new Error(`Failed to update user: ${response.status}`);
  }

  return response.json();
}

function isAdmin(user: any): boolean {
  return user.role === "admin";
}

function formatUserDisplay(user: any): string {
  return `${user.displayName} (${user.email})`;
}

function processUserList(users: any[]): any[] {
  return users.filter((u: any) => u.role !== "viewer").map((u: any) => ({
    id: u.id,
    label: formatUserDisplay(u),
  }));
}

export { fetchUser, createUser, updateUser, isAdmin, processUserList };
