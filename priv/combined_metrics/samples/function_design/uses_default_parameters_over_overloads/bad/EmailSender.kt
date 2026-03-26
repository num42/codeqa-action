package com.example.email

class EmailSender(private val smtpClient: SmtpClient) {

    // Multiple overloads instead of one function with default parameters

    fun send(to: String, subject: String, body: String): SendResult {
        return send(to, subject, body, emptyList())
    }

    fun send(to: String, subject: String, body: String, cc: List<String>): SendResult {
        return send(to, subject, body, cc, emptyList())
    }

    fun send(to: String, subject: String, body: String, cc: List<String>, bcc: List<String>): SendResult {
        return send(to, subject, body, cc, bcc, null)
    }

    fun send(to: String, subject: String, body: String, cc: List<String>, bcc: List<String>, replyTo: String?): SendResult {
        return send(to, subject, body, cc, bcc, replyTo, false)
    }

    fun send(to: String, subject: String, body: String, cc: List<String>, bcc: List<String>, replyTo: String?, isHtml: Boolean): SendResult {
        return send(to, subject, body, cc, bcc, replyTo, isHtml, EmailPriority.NORMAL)
    }

    fun send(
        to: String,
        subject: String,
        body: String,
        cc: List<String>,
        bcc: List<String>,
        replyTo: String?,
        isHtml: Boolean,
        priority: EmailPriority
    ): SendResult {
        val message = EmailMessage(to, subject, body, cc, bcc, replyTo, isHtml, priority)
        return smtpClient.dispatch(message)
    }

    fun sendBatch(recipients: List<String>, subject: String, body: String): List<SendResult> {
        return recipients.map { send(it, subject, body) }
    }

    fun sendBatchHtml(recipients: List<String>, subject: String, body: String): List<SendResult> {
        return recipients.map { send(it, subject, body, emptyList(), emptyList(), null, true) }
    }
}
