class User:
    def is_admin(self):
        return self.role == "admin"

    def has_permission(self, perm):
        return perm in self.permissions

    def is_active(self):
        return not self.banned and self.confirmed_at is not None

    def is_verified(self):
        return self.email_verified and self.phone_verified

    def is_expired(self):
        return self.expires_at < datetime.now()

    def has_valid_subscription(self):
        return self.subscription and not self.subscription.expired
