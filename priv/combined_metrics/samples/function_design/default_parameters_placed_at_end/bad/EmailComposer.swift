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

    // Default parameters intermixed with required ones, making call sites confusing
    func compose(
        cc: [String] = [],           // default before required params
        to recipients: [String],      // required
        isHTML: Bool = false,         // default before more required params
        subject: String,              // required
        attachments: [URL] = [],      // default
        body: String,                 // required — buried after defaults
        bcc: [String] = []
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

    // Default parameter (includeGettingStartedGuide) appears before required "name"
    func sendWelcome(
        to recipient: String,
        includeGettingStartedGuide: Bool = true,  // default before required
        name: String,                              // required after default
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

    // Default "retryCount" before required "date"
    func scheduleDelivery(
        for message: EmailMessage,
        retryCount: Int = 3,        // default before required
        at date: Date,              // required after default
        retryDelay: TimeInterval = 60
    ) {
        _ = (message, date, retryCount, retryDelay)
    }
}
