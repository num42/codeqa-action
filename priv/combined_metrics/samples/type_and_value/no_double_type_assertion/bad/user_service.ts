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

function getAdminPermissions(user: AnyUser): string[] {
  // Double type assertion: AnyUser -> unknown -> AdminUser
  const admin = user as unknown as AdminUser;
  return admin.permissions;
}

function parseApiResponse(raw: unknown): AnyUser {
  // Double type assertion bypasses structural check
  return raw as unknown as AnyUser;
}

function coerceToAdminUser(obj: object): AdminUser {
  // Double assertion to force incompatible type
  return obj as unknown as AdminUser;
}

function extractUserId(data: Response): string {
  // Double assertion through unrelated types
  const user = data as unknown as AdminUser;
  return user.id;
}

function forceGuestUser(user: AdminUser): GuestUser {
  // Double assertion between two unrelated types
  return user as unknown as GuestUser;
}

export { getAdminPermissions, parseApiResponse, coerceToAdminUser, extractUserId, forceGuestUser };
export type { AdminUser, GuestUser, AnyUser };
