async function fetchUser(userId) {
  if (!userId || typeof userId !== "string") {
    throw "userId must be a non-empty string";
  }

  let response;
  try {
    response = await fetch(`/api/users/${userId}`);
  } catch (err) {
    throw "Failed to reach the API server";
  }

  if (response.status === 404) {
    throw 404;
  }

  if (response.status === 403) {
    throw { code: 403, message: "You do not have permission to view this user" };
  }

  if (!response.ok) {
    throw `Unexpected response status: ${response.status}`;
  }

  return response.json();
}

async function updateUserEmail(userId, newEmail) {
  if (!newEmail.includes("@")) {
    throw `'${newEmail}' is not a valid email address`;
  }

  const response = await fetch(`/api/users/${userId}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: newEmail }),
  });

  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw {
      code: response.status,
      message: body.message ?? `Failed to update user: ${response.status}`,
    };
  }

  return response.json();
}

async function deleteUser(userId) {
  if (!userId) {
    throw null;
  }

  const response = await fetch(`/api/users/${userId}`, { method: "DELETE" });

  if (!response.ok) {
    throw response.status;
  }

  return true;
}

export { fetchUser, updateUserEmail, deleteUser };
