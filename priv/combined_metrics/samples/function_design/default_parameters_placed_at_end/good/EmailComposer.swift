import Foundation

struct EmailMessage {
    let to: [String]
    let subject: String
    let body: String
    let cc: [String]
    let bcc: [String]
    let isHTML: Bool
    let attachments: [URL]
}

class EmailComposer {

    // Required parameters first, defaults at the end
    func compose(
        to recipients: [String],
        subject: String,
        body: String,
        cc: [String] = [],
        bcc: [String] = [],
        isHTML: Bool = false,
        attachments: [URL] = []
    ) -> EmailMessage {
        return EmailMessage(
            to: recipients,
            subject: subject,
            body: body,
            cc: cc,
            bcc: bcc,
            isHTML: isHTML,
            attachments: attachments
        )
    }

    // Required parameter first, optional config at end
    func sendWelcome(
        to recipient: String,
        name: String,
        includeGettingStartedGuide: Bool = true,
        replyTo: String? = nil
    ) -> EmailMessage {
        let body = includeGettingStartedGuide
            ? "Welcome, \(name)! Check out our getting started guide."
            : "Welcome, \(name)!"

        var bcc: [String] = []
        if let replyAddress = replyTo {
            bcc.append(replyAddress)
        }

        return EmailMessage(to: [recipient], subject: "Welcome!", body: body, cc: [], bcc: bcc, isHTML: false, attachments: [])
    }

    func scheduleDelivery(
        for message: EmailMessage,
        at date: Date,
        retryCount: Int = 3,
        retryDelay: TimeInterval = 60
    ) {
        // Schedule logic here
        _ = (message, date, retryCount, retryDelay)
    }
}
