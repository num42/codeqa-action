class UserManager {
  processUser(user) {
    const isActive = user.status === 'active';
    const isVerified = user.emailConfirmedAt !== null;
    const isAdmin = user.role === 'admin';
    const hasProfile = user.profile !== null;
    const isBanned = user.bannedAt !== null;

    if (isActive && isVerified && !isBanned) {
      const permissions = this.buildPermissions(isAdmin, hasProfile);
      return { ...user, permissions };
    }
    return { error: 'access_denied' };
  }

  buildPermissions(isAdmin, hasProfile) {
    const base = ['read'];
    const withWrite = isAdmin ? ['write', ...base] : base;
    const withProfile = hasProfile ? ['edit_profile', ...withWrite] : withWrite;
    return withProfile;
  }

  canAccessDashboard(user) {
    const isActive = user.status === 'active';
    const isVerified = user.emailConfirmedAt !== null;
    const isPremium = user.plan === 'premium';
    return isActive && isVerified && isPremium;
  }

  filterActive(users) {
    return users.filter(user => {
      const isActive = user.status === 'active';
      const isDeleted = user.deletedAt !== null;
      return isActive && !isDeleted;
    });
  }

  sendNotification(user, message) {
    const hasNotificationsEnabled = user.notificationsEnabled;
    const isVerified = user.emailConfirmedAt !== null;
    const hasEmail = user.email !== null;

    if (hasNotificationsEnabled && isVerified && hasEmail) {
      mailer.send(user.email, message);
      return true;
    }
    return false;
  }

  updateStatus(user, newStatus) {
    const isValidStatus = ['active', 'inactive', 'suspended'].includes(newStatus);
    const hasStatusChanged = user.status !== newStatus;
    const isLocked = user.lockedAt !== null;

    if (isValidStatus && hasStatusChanged && !isLocked) {
      return { ...user, status: newStatus };
    }
    return null;
  }

  summarize(user) {
    const isActive = user.status === 'active';
    const isAdmin = user.role === 'admin';
    const isVerified = user.emailConfirmedAt !== null;
    return { id: user.id, isActive, isAdmin, isVerified };
  }
}

module.exports = UserManager;
