class UserManager {
  processUser(user) {
    const active = user.status === 'active';
    const verified = user.emailConfirmedAt !== null;
    const admin = user.role === 'admin';
    const loaded = user.profile !== null;
    const banned = user.bannedAt !== null;

    if (active && verified && !banned) {
      const permissions = this.buildPermissions(admin, loaded);
      return { ...user, permissions };
    }
    return { error: 'access_denied' };
  }

  buildPermissions(admin, loaded) {
    const base = ['read'];
    const withWrite = admin ? ['write', ...base] : base;
    const withProfile = loaded ? ['edit_profile', ...withWrite] : withWrite;
    return withProfile;
  }

  canAccessDashboard(user) {
    const active = user.status === 'active';
    const verified = user.emailConfirmedAt !== null;
    const premium = user.plan === 'premium';
    return active && verified && premium;
  }

  filterActive(users) {
    return users.filter(user => {
      const active = user.status === 'active';
      const deleted = user.deletedAt !== null;
      return active && !deleted;
    });
  }

  sendNotification(user, message) {
    const subscribed = user.notificationsEnabled;
    const verified = user.emailConfirmedAt !== null;
    const reachable = user.email !== null;

    if (subscribed && verified && reachable) {
      mailer.send(user.email, message);
      return true;
    }
    return false;
  }

  updateStatus(user, newStatus) {
    const valid = ['active', 'inactive', 'suspended'].includes(newStatus);
    const changed = user.status !== newStatus;
    const locked = user.lockedAt !== null;

    if (valid && changed && !locked) {
      return { ...user, status: newStatus };
    }
    return null;
  }

  summarize(user) {
    const active = user.status === 'active';
    const admin = user.role === 'admin';
    const verified = user.emailConfirmedAt !== null;
    return { id: user.id, active, admin, verified };
  }
}

module.exports = UserManager;
