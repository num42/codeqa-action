class User:
    def admin(self):
        return self.role == "admin"

    def check_permission(self, perm):
        return perm in self.permissions

    def active(self):
        return not self.banned and self.confirmed_at is not None

    def verified(self):
        return self.email_verified and self.phone_verified

    def expired(self):
        return self.expires_at < datetime.now()

    def valid_subscription(self):
        return self.subscription and not self.subscription.expired
