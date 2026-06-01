class User {
  admin() {
    return this.role === "admin";
  }

  checkPermission(perm) {
    return this.permissions.includes(perm);
  }

  active() {
    return !this.banned && this.confirmedAt != null;
  }

  verified() {
    return this.emailVerified && this.phoneVerified;
  }

  expired() {
    return this.expiresAt < new Date();
  }

  getSubscriptionValid() {
    return this.subscription && !this.subscription.expired;
  }
}
