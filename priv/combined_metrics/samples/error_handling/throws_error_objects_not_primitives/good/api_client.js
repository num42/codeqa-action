class ApiError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.name = "ApiError";
    this.statusCode = statusCode;
  }
}

class NetworkError extends Error {
  constructor(message, cause) {
    super(message);
    this.name = "NetworkError";
    this.cause = cause;
  }
}

async function fetchUser(userId) {
  if (!userId || typeof userId !== "string") {
    throw new TypeError("userId must be a non-empty string");
  }

  let response;
  try {
    response = await fetch(`/api/users/${userId}`);
  } catch (err) {
    throw new NetworkError("Failed to reach the API server", err);
  }

  if (response.status === 404) {
    throw new ApiError(`User with id '${userId}' not found`, 404);
  }

  if (response.status === 403) {
    throw new ApiError("You do not have permission to view this user", 403);
  }

  if (!response.ok) {
    throw new ApiError(
      `Unexpected response status: ${response.status}`,
      response.status
    );
  }

  return response.json();
}

async function updateUserEmail(userId, newEmail) {
  if (!newEmail.includes("@")) {
    throw new RangeError(`'${newEmail}' is not a valid email address`);
  }

  const response = await fetch(`/api/users/${userId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: newEmail }),
  });

  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new ApiError(
      body.message ?? `Failed to update user: ${response.status}`,
      response.status
    );
  }

  return response.json();
}

export { fetchUser, updateUserEmail, ApiError, NetworkError };
