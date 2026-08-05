import Foundation

actor MonthlyStoryAudioCache {
    enum CacheError: Error { case invalidData, writeFailed }

    private let root: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        root = base.appendingPathComponent("MonthlyStoryAudio", isDirectory: true)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true,
                                         attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableRoot = root
        try? mutableRoot.setResourceValues(values)
    }

    func existingURL(for story: MonthlyStoryDocument) -> URL? {
        let url = fileURL(for: story)
        guard FileManager.default.fileExists(atPath: url.path),
              (try? Data(contentsOf: url).count) ?? 0 > 4 else { return nil }
        return url
    }

    func store(_ data: Data, for story: MonthlyStoryDocument) throws -> URL {
        guard data.count > 4, data.count <= 25 * 1024 * 1024 else { throw CacheError.invalidData }
        let url = fileURL(for: story)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                                  ofItemAtPath: url.path)
            return url
        } catch { throw CacheError.writeFailed }
    }

    func remove(monthKey: MonthlyStoryMonthKey) {
        let prefix = monthKey.rawValue.replacingOccurrences(of: "-", with: "_") + "_"
        let files = (try? FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(prefix) { try? FileManager.default.removeItem(at: file) }
    }

    func removeAll() { try? FileManager.default.removeItem(at: root) }

    private func fileURL(for story: MonthlyStoryDocument) -> URL {
        let safeVersion = story.generationVersion.replacingOccurrences(of: "[^A-Za-z0-9._-]",
            with: "_", options: .regularExpression)
        let hash = story.audioHash ?? "pending"
        return root.appendingPathComponent("\(story.monthKey.rawValue.replacingOccurrences(of: "-", with: "_"))_\(safeVersion)_\(hash).mp3")
    }
}
