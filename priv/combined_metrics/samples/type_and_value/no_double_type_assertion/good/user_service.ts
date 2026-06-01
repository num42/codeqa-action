interface AdminUser {
  id: string;
  email: string;
  role: "admin";
  permissions: string[];
}

interface GuestUser {
  sessionId: string;
  role: "guest";
  expiresAt: number;
}

type AnyUser = AdminUser | GuestUser;

function isAdminUser(user: AnyUser): user is AdminUser {
  return user.role === "admin";
}

function isGuestUser(user: AnyUser): user is GuestUser {
  return user.role === "guest";
}

function getAdminPermissions(user: AnyUser): string[] {
  if (!isAdminUser(user)) {
    throw new Error("User is not an admin");
  }
  return user.permissions;
}

function parseApiResponse(raw: unknown): AnyUser {
  if (typeof raw !== "object" || raw === null) {
    throw new TypeError("Expected an object");
  }

  const obj = raw as Record<string, unknown>;

  if (obj["role"] === "admin") {
    if (typeof obj["id"] !== "string" || typeof obj["email"] !== "string") {
      throw new TypeError("Invalid admin user shape");
    }
    return {
      id: obj["id"],
      email: obj["email"],
      role: "admin",
      permissions: Array.isArray(obj["permissions"])
        ? (obj["permissions"] as string[])
        : [],
    };
  }

  if (obj["role"] === "guest") {
    if (typeof obj["sessionId"] !== "string" || typeof obj["expiresAt"] !== "number") {
      throw new TypeError("Invalid guest user shape");
    }
    return {
      sessionId: obj["sessionId"],
      role: "guest",
      expiresAt: obj["expiresAt"],
    };
  }

  throw new TypeError(`Unknown user role: ${obj["role"]}`);
}

export { getAdminPermissions, parseApiResponse, isAdminUser, isGuestUser };
export type { AdminUser, GuestUser, AnyUser };
