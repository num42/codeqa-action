package com.example.notifications

data class NotificationPreferences(
    val emailEnabled: Boolean?,
    val pushEnabled: Boolean?,
    val smsEnabled: Boolean?,
    val marketingOptIn: Boolean?
)

class NotificationHandler(
    private val emailSender: EmailSender,
    private val pushSender: PushSender,
    private val smsSender: SmsSender
) {

    fun dispatch(userId: String, prefs: NotificationPreferences?, message: String) {
        // Explicit == true comparison for nullable Boolean — false and null are both excluded
        if (prefs?.emailEnabled == true) {
            emailSender.send(userId, message)
        }

        if (prefs?.pushEnabled == true) {
            pushSender.send(userId, message)
        }

        if (prefs?.smsEnabled == true) {
            smsSender.send(userId, message)
        }
    }

    fun isMarketingAllowed(prefs: NotificationPreferences?): Boolean {
        // == true makes null-safety intent clear: null means not opted in
        return prefs?.marketingOptIn == true
    }

    fun sendIfAllChannelsEnabled(userId: String, prefs: NotificationPreferences?, message: String) {
        val allEnabled = prefs?.emailEnabled == true
                && prefs.pushEnabled == true
                && prefs.smsEnabled == true
        if (allEnabled) {
            emailSender.send(userId, message)
            pushSender.send(userId, message)
            smsSender.send(userId, message)
        }
    }

    fun anyChannelDisabled(prefs: NotificationPreferences?): Boolean {
        // == false explicitly checks for false, excluding null (which means unknown)
        return prefs?.emailEnabled == false
                || prefs?.pushEnabled == false
                || prefs?.smsEnabled == false
    }
}
