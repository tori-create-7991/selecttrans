import Foundation

actor MarkdownHistoryStore {
    static let shared = MarkdownHistoryStore(directory: defaultDirectory)

    static let defaultDirectory: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NaniMini/history", isDirectory: true)

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func save(_ record: TranslationRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        let date = ISO8601DateFormatter().date(from: record.date) ?? Date()
        let file = directory.appendingPathComponent("\(formatter.string(from: date)).md")
        let entry = """

        ## \(record.date)
        - Engine: \(record.engine)
        - Direction: \(record.direction)
        - Mode: \(record.mode)
        - App: \(record.app)

        ### Source
        \(record.source)

        ### Result
        \(record.result)

        """
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(entry.utf8))
            try handle.close()
        } else {
            try Data(entry.utf8).write(to: file, options: .atomic)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
