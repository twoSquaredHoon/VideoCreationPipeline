import Foundation

enum ProjectPhase: String, Codable {
    case creatingScript
    case scriptReview
    case generatingPrompts
    case promptsReview
    case generatingVoiceover
    case voiceoverReview
    case generatingVideos
    case ready
    case failed
}

enum ProjectLanguage: String, Codable, CaseIterable, Hashable {
    case en
    case ko
    case es

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어 (Korean)"
        case .es: return "Español (Spanish)"
        }
    }

    var shortLabel: String {
        switch self {
        case .en: return "EN"
        case .ko: return "KO"
        case .es: return "ES"
        }
    }
}

enum ArticleReviewStatus: String, Codable, Hashable {
    case passed
    case failed
}

struct ProjectManifest: Codable, Hashable {
    var id: String
    var title: String
    var blogURL: String
    var createdAt: String
    var phase: ProjectPhase
    var language: ProjectLanguage
    var lastError: String?
    var articleReviewStatus: ArticleReviewStatus?
    var articleReviewNotes: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case blogURL = "blog_url"
        case createdAt = "created_at"
        case phase
        case language
        case lastError = "last_error"
        case articleReviewStatus = "article_review_status"
        case articleReviewNotes = "article_review_notes"
    }

    init(
        id: String,
        title: String,
        blogURL: String,
        createdAt: String,
        phase: ProjectPhase,
        language: ProjectLanguage = .en,
        lastError: String?,
        articleReviewStatus: ArticleReviewStatus? = nil,
        articleReviewNotes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.blogURL = blogURL
        self.createdAt = createdAt
        self.phase = phase
        self.language = language
        self.lastError = lastError
        self.articleReviewStatus = articleReviewStatus
        self.articleReviewNotes = articleReviewNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        blogURL = try container.decode(String.self, forKey: .blogURL)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        phase = try container.decode(ProjectPhase.self, forKey: .phase)
        language = try container.decodeIfPresent(ProjectLanguage.self, forKey: .language) ?? .en
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        articleReviewStatus = try container.decodeIfPresent(ArticleReviewStatus.self, forKey: .articleReviewStatus)
        articleReviewNotes = try container.decodeIfPresent(String.self, forKey: .articleReviewNotes)
    }
}

struct ClipRecord: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var detailedPrompt: String?
    var veoPrompt: String?
    var durationSeconds: Int?
    var scriptLine: String?

    enum CodingKeys: String, CodingKey {
        case id, label
        case detailedPrompt = "detailed_prompt"
        case veoPrompt = "veo_prompt"
        case durationSeconds = "duration_seconds"
        case scriptLine = "script_line"
    }
}

struct ClipsFile: Codable {
    let clips: [ClipRecord]
}

struct VideoProject: Identifiable, Hashable {
    let id: String
    let folderURL: URL
    var manifest: ProjectManifest

    var scriptURL: URL { folderURL.appendingPathComponent("script.txt") }
    var decisionsURL: URL { folderURL.appendingPathComponent("clip_decisions.txt") }
    var promptsURL: URL { folderURL.appendingPathComponent("clip_prompts.txt") }
    var clipsJSONURL: URL { folderURL.appendingPathComponent("clips.json") }
    /// Single file: blog, script, and clip prompts.
    var scriptPromptsURL: URL { folderURL.appendingPathComponent("script_prompts.txt") }
    var logURL: URL { folderURL.appendingPathComponent("pipeline.log") }
    var voiceoverURL: URL { folderURL.appendingPathComponent("voiceover.wav") }
    var speechURL: URL { folderURL.appendingPathComponent("speech.txt") }
    var voiceoverMetaURL: URL { folderURL.appendingPathComponent("voiceover_meta.json") }
    var videosURL: URL { folderURL.appendingPathComponent("videos", isDirectory: true) }

    func videoURL(for clipID: String) -> URL {
        videosURL.appendingPathComponent("\(clipID).mp4")
    }

    func resolvedVideoURL(for clipID: String) -> URL? {
        let candidates = [
            videoURL(for: clipID),
            LanguageWorkspace.directory(for: self, language: manifest.language)
                .appendingPathComponent("videos/\(clipID).mp4"),
        ]
        for url in candidates {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int, size > 1000 else { continue }
            return url
        }
        return nil
    }

    func hasVideo(for clipID: String) -> Bool {
        resolvedVideoURL(for: clipID) != nil
    }

    var hasScript: Bool {
        FileManager.default.fileExists(atPath: scriptURL.path)
    }

    var hasClipsJSON: Bool {
        FileManager.default.fileExists(atPath: clipsJSONURL.path)
    }

    func hasScript(for language: ProjectLanguage) -> Bool {
        if language == manifest.language { return hasScript }
        return LanguageWorkspace.hasScript(in: LanguageWorkspace.directory(for: self, language: language))
    }

    func hasClipsJSON(for language: ProjectLanguage) -> Bool {
        if language == manifest.language { return hasClipsJSON }
        return LanguageWorkspace.hasClipsJSON(in: LanguageWorkspace.directory(for: self, language: language))
    }

    func hasVoiceover(for language: ProjectLanguage) -> Bool {
        if language == manifest.language { return hasVoiceover }
        return LanguageWorkspace.hasVoiceover(in: LanguageWorkspace.directory(for: self, language: language))
    }

    func hasAnyWork(for language: ProjectLanguage) -> Bool {
        let langDir = LanguageWorkspace.directory(for: self, language: language)
        if LanguageWorkspace.hasAnyWork(in: langDir) { return true }
        if !loadWorkflowGraph(for: language).nodes.isEmpty { return true }
        if language == manifest.language {
            return hasScript || hasClipsJSON || hasVoiceover
        }
        return false
    }

    func loadClips(for language: ProjectLanguage) -> [ClipRecord] {
        if language == manifest.language { return loadClips() }
        return LanguageWorkspace.loadClips(from: LanguageWorkspace.directory(for: self, language: language))
    }

    func videoStatus(for language: ProjectLanguage, clips: [ClipRecord]) -> (done: Int, total: Int) {
        if language == manifest.language { return videoStatus(for: clips) }
        let dir = LanguageWorkspace.directory(for: self, language: language)
        return LanguageWorkspace.videoStatus(for: dir, clips: clips)
    }

    func loadWorkflowGraph(for language: ProjectLanguage) -> WorkflowGraphFile {
        WorkflowGraphManager(projectFolder: folderURL, language: language).load()
    }

    var hasVoiceover: Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: voiceoverURL.path),
              let size = attrs[.size] as? Int else { return false }
        return size > 1000
    }

    func loadScript() -> String {
        (try? String(contentsOf: scriptURL, encoding: .utf8)) ?? ""
    }

    func loadDecisions() -> String {
        (try? String(contentsOf: decisionsURL, encoding: .utf8)) ?? ""
    }

    func loadClips() -> [ClipRecord] {
        guard let data = try? Data(contentsOf: clipsJSONURL),
              let file = try? JSONDecoder().decode(ClipsFile.self, from: data) else {
            return []
        }
        return file.clips.sorted { Self.sortKey(for: $0.id) < Self.sortKey(for: $1.id) }
    }

    func saveClips(_ clips: [ClipRecord]) throws {
        let sorted = clips.sorted { Self.sortKey(for: $0.id) < Self.sortKey(for: $1.id) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(ClipsFile(clips: sorted))
        try data.write(to: clipsJSONURL, options: .atomic)
        try formatClipPromptsText(sorted).write(to: promptsURL, atomically: true, encoding: .utf8)
        try writeScriptPromptsFile(clips: sorted)
    }

    /// Rebuild `script_prompts.txt` from current project files (blog, script, prompts).
    @discardableResult
    func writeScriptPromptsFile(clips: [ClipRecord]? = nil) throws -> URL {
        let text = buildScriptPromptsText(clips: clips ?? loadClips())
        try text.write(to: scriptPromptsURL, atomically: true, encoding: .utf8)
        return scriptPromptsURL
    }

    func buildScriptPromptsText(clips: [ClipRecord]? = nil) -> String {
        let clipList = clips ?? loadClips()
        let article = loadSourceArticle().trimmingCharacters(in: .whitespacesAndNewlines)
        let script = loadScript().trimmingCharacters(in: .whitespacesAndNewlines)
        let decisions = loadDecisions().trimmingCharacters(in: .whitespacesAndNewlines)
        let cast = (try? String(contentsOf: folderURL.appendingPathComponent("visual_cast.txt"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var parts: [String] = []
        parts.append("# Script prompts — blog, script, and clip prompts")
        parts.append("")
        parts.append("## Meta")
        parts.append("- Title: \(manifest.title)")
        parts.append("- Language: \(manifest.language.rawValue)")
        parts.append("- Blog URL: \(manifest.blogURL)")
        parts.append("- Project folder: \(folderURL.path)")
        parts.append("")

        parts.append("## Blog / source article")
        parts.append("")
        if article.isEmpty {
            parts.append("(No source_article.txt yet — compare script to article to fetch it, or use the blog URL above.)")
        } else {
            parts.append(article)
        }
        parts.append("")

        parts.append("## Video script")
        parts.append("")
        parts.append(script.isEmpty ? "(No script.txt yet.)" : script)
        parts.append("")

        if !cast.isEmpty {
            parts.append("## Visual cast")
            parts.append("")
            parts.append(cast)
            parts.append("")
        }

        if !decisions.isEmpty {
            parts.append("## Clip decisions")
            parts.append("")
            parts.append(decisions)
            parts.append("")
        }

        parts.append("## Clip prompts (edit these — detailed prompt is used for video)")
        parts.append("")
        if clipList.isEmpty {
            parts.append("(No clips.json yet.)")
        } else {
            for clip in clipList {
                parts.append("### \(clip.label) (`\(clip.id)`)")
                if let seconds = clip.durationSeconds {
                    parts.append("- Duration: \(seconds)s")
                }
                if let line = clip.scriptLine, !line.isEmpty {
                    parts.append("- Script line: \(line)")
                }
                parts.append("")
                parts.append("#### Detailed prompt")
                parts.append("")
                parts.append((clip.detailedPrompt ?? "").isEmpty ? "(empty)" : clip.detailedPrompt!)
                parts.append("")
                parts.append("#### Veo prompt")
                parts.append("")
                parts.append((clip.veoPrompt ?? "").isEmpty ? "(empty)" : clip.veoPrompt!)
                parts.append("")
                parts.append("---")
                parts.append("")
            }
        }

        return parts.joined(separator: "\n")
    }

    private func formatClipPromptsText(_ clips: [ClipRecord]) -> String {
        var lines: [String] = ["# Clip prompts\n"]
        for clip in clips {
            lines.append("## \(clip.label) (\(clip.id))\n\n")
            lines.append(clip.detailedPrompt ?? "")
            lines.append("\n\n**Veo prompt:**\n\n")
            lines.append(clip.veoPrompt ?? "")
            lines.append("\n\n")
        }
        return lines.joined()
    }

    static func sortKey(for id: String) -> (Int, Int) {
        if id == "hook" { return (0, 0) }
        if id.hasPrefix("body_"), let n = Int(id.dropFirst(5)) { return (1, n) }
        if id.hasPrefix("explain_"), let n = Int(id.dropFirst(8)) { return (2, n) }
        if id.hasPrefix("signs_"), let n = Int(id.dropFirst(6)) { return (3, n) }
        if id == "relief" { return (4, 0) }
        if id == "cta" { return (5, 0) }
        if id.hasPrefix("custom_"), let n = Int(id.dropFirst(7)) { return (3, 500 + n) }
        return (99, 0)
    }

    func clipSortKey(_ id: String) -> (Int, Int) {
        Self.sortKey(for: id)
    }

    func videoStatus(for clips: [ClipRecord]) -> (done: Int, total: Int) {
        let total = clips.count
        let done = clips.filter { hasVideo(for: $0.id) }.count
        return (done, total)
    }

    static func slug(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "project" }
        let last = url.pathComponents.last ?? "project"
        let cleaned = last.lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\-]"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return String(cleaned.prefix(50)).isEmpty ? "project" : String(cleaned.prefix(50))
    }

    static func title(from script: String) -> String {
        for line in script.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || t.hasPrefix("#") { continue }
            if t.uppercased().hasSuffix(":") && t.count < 20 { continue }
            return String(t.prefix(72))
        }
        return "Untitled project"
    }
}
