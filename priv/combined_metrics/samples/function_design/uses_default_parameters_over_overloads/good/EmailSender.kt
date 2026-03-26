package com.example.email

data class EmailMessage(
    val to: String,
    val subject: String,
    val body: String,
    val cc: List<String> = emptyList(),
    val bcc: List<String> = emptyList(),
    val replyTo: String? = null,
    val isHtml: Boolean = false,
    val priority: EmailPriority = EmailPriority.NORMAL
)

class EmailSender(private val smtpClient: SmtpClient) {

    // Single function with default parameters instead of multiple overloads
    fun send(
        to: String,
        subject: String,
        body: String,
        cc: List<String> = emptyList(),
        bcc: List<String> = emptyList(),
        replyTo: String? = null,
        isHtml: Boolean = false,
        priority: EmailPriority = EmailPriority.NORMAL
    ): SendResult {
        val message = EmailMessage(
            to = to,
            subject = subject,
            body = body,
            cc = cc,
            bcc = bcc,
            replyTo = replyTo,
            isHtml = isHtml,
            priority = priority
        )
        return smtpClient.dispatch(message)
    }

    fun sendBatch(
        recipients: List<String>,
        subject: String,
        body: String,
        isHtml: Boolean = false,
        priority: EmailPriority = EmailPriority.NORMAL
    ): List<SendResult> {
        return recipients.map { send(it, subject, body, isHtml = isHtml, priority = priority) }
    }
}
