class User {
  isAdmin() {
    return this.role === "admin";
  }

  hasPermission(perm) {
    return this.permissions.includes(perm);
  }

  isActive() {
    return !this.banned && this.confirmedAt != null;
  }

  isVerified() {
    return this.emailVerified && this.phoneVerified;
  }

  isExpired() {
    return this.expiresAt < new Date();
  }

  hasValidSubscription() {
    return this.subscription && !this.subscription.expired;
  }
}
