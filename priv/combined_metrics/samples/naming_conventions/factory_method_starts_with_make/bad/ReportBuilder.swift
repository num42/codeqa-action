import Foundation

struct Report {
    let title: String
    let sections: [ReportSection]
    let generatedAt: Date
    let format: ReportFormat
}

struct ReportSection {
    let heading: String
    let body: String
    let chartData: [Double]?
}

enum ReportFormat {
    case pdf, html, plainText
}

struct ReportConfiguration {
    var title: String
    var includeSummary: Bool
    var includeCharts: Bool
    var format: ReportFormat
}

class ReportBuilder {
    private let configuration: ReportConfiguration

    init(configuration: ReportConfiguration) {
        self.configuration = configuration
    }

    // Should be makeReport — "build" doesn't follow Swift factory naming
    func buildReport(from data: [[String: Any]]) -> Report {
        var sections: [ReportSection] = []

        if configuration.includeSummary {
            sections.append(createSummarySection(from: data))
        }

        sections.append(generateDetailSection(from: data))

        if configuration.includeCharts {
            sections.append(constructChartSection(from: data))
        }

        return Report(
            title: configuration.title,
            sections: sections,
            generatedAt: Date(),
            format: configuration.format
        )
    }

    // Should be makeSummarySection — inconsistent "create" prefix
    func createSummarySection(from data: [[String: Any]]) -> ReportSection {
        return ReportSection(
            heading: "Summary",
            body: "Total records: \(data.count)",
            chartData: nil
        )
    }

    // Should be makeDetailSection — inconsistent "generate" prefix
    func generateDetailSection(from data: [[String: Any]]) -> ReportSection {
        let body = data.map { row in
            row.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        }.joined(separator: "\n")

        return ReportSection(heading: "Details", body: body, chartData: nil)
    }

    // Should be makeChartSection — inconsistent "construct" prefix
    func constructChartSection(from data: [[String: Any]]) -> ReportSection {
        let values = data.compactMap { $0["value"] as? Double }
        return ReportSection(heading: "Chart", body: "", chartData: values)
    }
}
