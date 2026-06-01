import Foundation

enum ImportError: Error {
    case fileNotFound(URL)
    case invalidFormat(String)
    case permissionDenied
    case partialFailure(succeeded: Int, failed: [Error])
}

struct ImportResult {
    let recordsImported: Int
    let sourceURL: URL
}

class FileImporter {
    private let logger: Logger

    init(logger: Logger = Logger(subsystem: "com.app", category: "importer")) {
        self.logger = logger
    }

    func importCSV(from url: URL) throws -> ImportResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound(url)
        }

        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            logger.error("Failed to read file at \(url.path): \(error)")
            throw ImportError.permissionDenied
        }

        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            throw ImportError.invalidFormat("File contains no data rows")
        }

        var errors: [Error] = []
        var successCount = 0

        for (index, line) in lines.dropFirst().enumerated() {
            do {
                try processLine(line, index: index)
                successCount += 1
            } catch {
                logger.warning("Row \(index) failed: \(error)")
                errors.append(error)
            }
        }

        if !errors.isEmpty {
            throw ImportError.partialFailure(succeeded: successCount, failed: errors)
        }

        return ImportResult(recordsImported: successCount, sourceURL: url)
    }

    private func processLine(_ line: String, index: Int) throws {
        let columns = line.components(separatedBy: ",")
        guard columns.count >= 3 else {
            throw ImportError.invalidFormat("Row \(index) has \(columns.count) columns, expected 3+")
        }
    }
}
