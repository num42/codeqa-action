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
        // Treating nullable Boolean as truthy — null will NOT enter the block,
        // but this is ambiguous: is null "not set" or "disabled"?
        if (prefs?.emailEnabled!!) {
            emailSender.send(userId, message)
        }

        // Using ?: true coerces null to true — silently sends even without consent
        if (prefs?.pushEnabled ?: true) {
            pushSender.send(userId, message)
        }

        // Direct truthiness check on nullable — unclear intent
        if (prefs?.smsEnabled != null && prefs.smsEnabled) {
            smsSender.send(userId, message)
        }
    }

    fun isMarketingAllowed(prefs: NotificationPreferences?): Boolean {
        // Treating nullable Boolean directly as Boolean — won't compile cleanly
        // but shows the intent to skip explicit comparison
        return prefs?.marketingOptIn ?: false
    }

    fun sendIfAllChannelsEnabled(userId: String, prefs: NotificationPreferences?, message: String) {
        // Coercing nullable to false with ?: — null treated same as disabled,
        // but the intent is buried and easy to get wrong
        val allEnabled = (prefs?.emailEnabled ?: false)
                && (prefs?.pushEnabled ?: false)
                && (prefs?.smsEnabled ?: false)
        if (allEnabled) {
            emailSender.send(userId, message)
        }
    }
}
