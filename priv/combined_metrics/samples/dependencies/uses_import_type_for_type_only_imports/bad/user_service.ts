// Regular imports used for type-only symbols — should use `import type`
import { User, CreateUserPayload, UpdateUserPayload } from "./user_types.js";
import { PaginatedResponse, ApiError } from "./api_types.js";
import { buildApiUrl, handleResponse } from "./api_client.js";
import { formatDate } from "./date_utils.js";

async function fetchUser(userId: string): Promise<User> {
  const url = buildApiUrl(`/users/${userId}`);
  const response = await fetch(url);
  return handleResponse<User>(response);
}

async function createUser(payload: CreateUserPayload): Promise<User> {
  const url = buildApiUrl("/users");
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return handleResponse<User>(response);
}

async function updateUser(userId: string, changes: UpdateUserPayload): Promise<User> {
  const url = buildApiUrl(`/users/${userId}`);
  const response = await fetch(url, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(changes),
  });
  return handleResponse<User>(response);
}

async function listUsers(page = 1, pageSize = 20): Promise<PaginatedResponse<User>> {
  const url = buildApiUrl(`/users?page=${page}&pageSize=${pageSize}`);
  const response = await fetch(url);
  return handleResponse<PaginatedResponse<User>>(response);
}

function handleApiError(error: ApiError): void {
  console.error(`API error [${error.code}]: ${error.message}`);
}

function formatUserCreatedDate(user: User): string {
  return formatDate(user.createdAt);
}

export { fetchUser, createUser, updateUser, listUsers, handleApiError, formatUserCreatedDate };
