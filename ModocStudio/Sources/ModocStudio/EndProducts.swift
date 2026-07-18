import Foundation

struct EndProductMeta: Codable, Hashable {
    var projectPath: String?
    var importedAt: String?
    var originalFilename: String?

    enum CodingKeys: String, CodingKey {
        case projectPath = "project_path"
        case importedAt = "imported_at"
        case originalFilename = "original_filename"
    }
}

enum EndProductLocation: String, Hashable {
    case inbox
    case passed
}

struct EndProductItem: Identifiable, Hashable {
    let id: String
    let videoURL: URL
    let location: EndProductLocation
    let dateFolder: String?
    let meta: EndProductMeta?
    let review: VisualMedicalReviewReport?

    var displayName: String { videoURL.lastPathComponent }

    var linkedProject: VideoProject? {
        guard let path = meta?.projectPath else { return nil }
        return ProjectDiskLoader.loadProject(
            from: URL(fileURLWithPath: path),
            pipelineRunning: false
        )
    }

    var reviewDocumentURL: URL? {
        let url = EndProducts.reviewDocumentURL(for: videoURL)
        guard FileManager.default.fileExists(atPath: url.path)
            || review != nil else { return nil }
        return url
    }

    var reviewDocumentText: String? {
        EndProducts.loadReviewDocument(for: videoURL)
    }
}

/// End products: `output/end-products/inbox/` → review → `passed/YYYY-MM-DD/` on pass
enum EndProducts {
    static let videoExtensions = ["mp4", "mov"]

    static var rootURL: URL { ModocConfig.endProductsURL }
    static var inboxURL: URL { rootURL.appendingPathComponent("inbox", isDirectory: true) }
    static var passedURL: URL { rootURL.appendingPathComponent("passed", isDirectory: true) }

    static func ensureLayout() throws {
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: passedURL, withIntermediateDirectories: true)
    }

    static func isVideoFile(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    static func todayFolderID() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }

    static func passedDateURL(_ dateFolder: String) -> URL {
        passedURL.appendingPathComponent(dateFolder, isDirectory: true)
    }

    // MARK: - Paths

    static func metaURL(for video: URL) -> URL {
        video.deletingPathExtension().appendingPathExtension("meta.json")
    }

    static func reviewJSONURL(for video: URL) -> URL {
        video.deletingPathExtension().appendingPathExtension("review.json")
    }

    static func reviewTXTURL(for video: URL) -> URL {
        video.deletingPathExtension().appendingPathExtension("review.txt")
    }

    // MARK: - Import

    static func importToInbox(from source: URL, project: VideoProject? = nil) throws -> URL {
        try ensureLayout()
        guard isVideoFile(source) else {
            throw EndProductError.unsupportedFormat
        }

        let dest = uniqueInboxURL(preferredName: source.lastPathComponent)
        let normalizedSource = source.standardizedFileURL
        if normalizedSource != dest.standardizedFileURL {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: normalizedSource, to: dest)
        }

        let meta = EndProductMeta(
            projectPath: project?.folderURL.path,
            importedAt: ISO8601DateFormatter().string(from: Date()),
            originalFilename: source.lastPathComponent
        )
        try saveMeta(meta, for: dest)
        return dest
    }

    private static func uniqueInboxURL(preferredName: String) -> URL {
        let dest = inboxURL.appendingPathComponent(preferredName)
        guard FileManager.default.fileExists(atPath: dest.path) else { return dest }

        let stem = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        let stamp = {
            let f = DateFormatter()
            f.dateFormat = "HHmmss"
            return f.string(from: Date())
        }()
        return inboxURL.appendingPathComponent("\(stem)-\(stamp).\(ext)")
    }

    static func saveMeta(_ meta: EndProductMeta, for video: URL) throws {
        let data = try JSONEncoder().encode(meta)
        try data.write(to: metaURL(for: video))
    }

    static func loadMeta(for video: URL) -> EndProductMeta? {
        let url = metaURL(for: video)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(EndProductMeta.self, from: data)
    }

    static func loadReview(for video: URL) -> VisualMedicalReviewReport? {
        let url = reviewJSONURL(for: video)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VisualMedicalReviewReport.self, from: data)
    }

    static func reviewDocumentURL(for video: URL) -> URL {
        reviewTXTURL(for: video)
    }

    static func loadReviewDocument(for video: URL) -> String? {
        let docURL = reviewDocumentURL(for: video)
        if let text = try? String(contentsOf: docURL, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return loadReview(for: video)?.plainTextDocument()
    }

    static func writeReviewDocument(for video: URL, report: VisualMedicalReviewReport) throws {
        let text = report.plainTextDocument()
        try text.write(to: reviewDocumentURL(for: video), atomically: true, encoding: .utf8)
    }

    // MARK: - Scan

    static func listInboxItems() -> [EndProductItem] {
        scanVideos(in: inboxURL, location: .inbox, dateFolder: nil)
    }

    static func listPassedItems() -> [EndProductItem] {
        guard let dateFolders = try? FileManager.default.contentsOfDirectory(
            at: passedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return dateFolders
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .flatMap { folder in
                scanVideos(in: folder, location: .passed, dateFolder: folder.lastPathComponent)
            }
    }

    static func allItems() -> [EndProductItem] {
        listInboxItems() + listPassedItems()
    }

    private static func scanVideos(in folder: URL, location: EndProductLocation, dateFolder: String?) -> [EndProductItem] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries
            .filter { isVideoFile($0) }
            .compactMap { url -> EndProductItem? in
                guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                      size > 1000 else { return nil }
                return EndProductItem(
                    id: url.standardizedFileURL.path,
                    videoURL: url,
                    location: location,
                    dateFolder: dateFolder,
                    meta: loadMeta(for: url),
                    review: loadReview(for: url)
                )
            }
            .sorted { $0.videoURL.lastPathComponent.localizedCaseInsensitiveCompare($1.videoURL.lastPathComponent) == .orderedAscending }
    }

    // MARK: - Archive

    static func archivePassed(videoURL: URL) throws {
        let date = todayFolderID()
        let destDir = passedDateURL(date)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        var destVideo = destDir.appendingPathComponent(videoURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destVideo.path) {
            let stamp = {
                let f = DateFormatter()
                f.dateFormat = "HHmmss"
                return f.string(from: Date())
            }()
            destVideo = destDir.appendingPathComponent(
                "\(videoURL.deletingPathExtension().lastPathComponent)-\(stamp)\(videoURL.pathExtension)"
            )
        }

        try moveIfExists(from: videoURL, to: destVideo)
        try moveIfExists(from: metaURL(for: videoURL), to: destDir.appendingPathComponent(metaURL(for: videoURL).lastPathComponent))
        try moveIfExists(from: reviewJSONURL(for: videoURL), to: destDir.appendingPathComponent(reviewJSONURL(for: videoURL).lastPathComponent))
        try moveIfExists(from: reviewTXTURL(for: videoURL), to: destDir.appendingPathComponent(reviewTXTURL(for: videoURL).lastPathComponent))
    }

    private static func moveIfExists(from: URL, to: URL) throws {
        guard FileManager.default.fileExists(atPath: from.path) else { return }
        if FileManager.default.fileExists(atPath: to.path) {
            try FileManager.default.removeItem(at: to)
        }
        try FileManager.default.moveItem(at: from, to: to)
    }

    static func guessProject(in projects: [VideoProject], for videoURL: URL) -> VideoProject? {
        let stem = videoURL.deletingPathExtension().lastPathComponent.lowercased()
        if let exact = projects.first(where: { $0.folderURL.lastPathComponent.lowercased() == stem }) {
            return exact
        }
        return projects.first { proj in
            let name = proj.folderURL.lastPathComponent.lowercased()
            return stem.contains(name) || name.contains(stem)
        }
    }
}

enum EndProductError: LocalizedError {
    case unsupportedFormat
    case notFound

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Only .mp4 and .mov files are supported."
        case .notFound:
            return "Video not found in end-products inbox."
        }
    }
}
