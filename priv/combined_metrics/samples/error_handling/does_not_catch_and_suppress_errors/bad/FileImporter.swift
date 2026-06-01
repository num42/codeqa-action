import Foundation

struct ImportResult {
    let recordsImported: Int
    let sourceURL: URL
}

class FileImporter {

    func importCSV(from url: URL) -> ImportResult? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Silently swallowed — caller has no idea what went wrong
            return nil
        }

        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else {
            return nil
        }

        var successCount = 0

        for (index, line) in lines.dropFirst().enumerated() {
            do {
                try processLine(line, index: index)
                successCount += 1
            } catch {
                // Silently skipping bad rows — data loss with no notification
                continue
            }
        }

        // Returns a "success" even when half the rows were silently dropped
        return ImportResult(recordsImported: successCount, sourceURL: url)
    }

    func saveRecord(_ data: Data, to url: URL) {
        do {
            try data.write(to: url)
        } catch {
            // Error completely swallowed — caller thinks save succeeded
        }
    }

    private func processLine(_ line: String, index: Int) throws {
        let columns = line.components(separatedBy: ",")
        guard columns.count >= 3 else {
            throw NSError(domain: "ImportError", code: 1)
        }
    }
}
