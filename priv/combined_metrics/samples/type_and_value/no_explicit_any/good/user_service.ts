interface User {
  id: string;
  email: string;
  displayName: string;
  role: "admin" | "member" | "viewer";
  createdAt: string;
}

interface CreateUserPayload {
  email: string;
  displayName: string;
  role: User["role"];
}

interface UpdateUserPayload {
  displayName?: string;
  role?: User["role"];
}

interface ApiResponse<T> {
  data: T;
  meta: {
    requestId: string;
    timestamp: string;
  };
}

async function fetchUser(userId: string): Promise<User> {
  const response = await fetch(`/api/users/${userId}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch user ${userId}: ${response.status}`);
  }

  const body: ApiResponse<User> = await response.json();
  return body.data;
}

async function createUser(payload: CreateUserPayload): Promise<User> {
  const response = await fetch("/api/users", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const error: { message: string } = await response.json();
    throw new Error(error.message);
  }

  const body: ApiResponse<User> = await response.json();
  return body.data;
}

async function updateUser(userId: string, changes: UpdateUserPayload): Promise<User> {
  const response = await fetch(`/api/users/${userId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(changes),
  });

  if (!response.ok) {
    throw new Error(`Failed to update user: ${response.status}`);
  }

  const body: ApiResponse<User> = await response.json();
  return body.data;
}

function isAdmin(user: User): boolean {
  return user.role === "admin";
}

export { fetchUser, createUser, updateUser, isAdmin };
export type { User, CreateUserPayload, UpdateUserPayload };
