import Foundation

/// Loads and saves `config/video_prompts.json` — the single source for video-creation prompts.
@MainActor
final class VideoPromptsStore: ObservableObject {
    @Published var root: [String: Any] = [:]
    @Published var loadError: String?
    @Published var saveMessage: String?
    @Published var isDirty = false

    static var configURL: URL {
        ModocConfig.rootURL.appendingPathComponent("config/video_prompts.json")
    }

    func reload() {
        loadError = nil
        saveMessage = nil
        let url = Self.configURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            root = [:]
            loadError = "Missing config/video_prompts.json — create it under your modocAI folder."
            isDirty = false
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data)
            guard let dict = obj as? [String: Any] else {
                loadError = "video_prompts.json must be a JSON object."
                root = [:]
                return
            }
            root = dict
            isDirty = false
        } catch {
            loadError = error.localizedDescription
            root = [:]
        }
    }

    func save() {
        loadError = nil
        do {
            let url = Self.configURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            // Prefer readable UTF-8 (not escaped unicode)
            if let text = String(data: data, encoding: .utf8) {
                try text.write(to: url, atomically: true, encoding: .utf8)
            } else {
                try data.write(to: url, options: .atomic)
            }
            isDirty = false
            saveMessage = "Saved \(url.path)"
        } catch {
            loadError = "Save failed: \(error.localizedDescription)"
        }
    }

    func stringValue(for keyPath: [String]) -> String {
        guard let value = value(at: keyPath) else { return "" }
        if let s = value as? String { return s }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(describing: value)
    }

    func setStringValue(_ text: String, for keyPath: [String]) {
        guard !keyPath.isEmpty else { return }
        let leaf = keyPath.last ?? ""
        let objectLeaves: Set<String> = [
            "en", "ko", "es", "signs", "explain", "tts_voices", "clip_durations",
            "visual_cast", "tts", "script_rules", "script_system",
        ]
        // Nested language/cast/tts blocks are JSON objects; prompt bodies are plain strings.
        let treatAsJSON = keyPath.count == 1
            ? ["signs", "explain", "tts_voices", "clip_durations", "visual_cast", "tts", "script_rules", "script_system"].contains(leaf)
            : (keyPath.first.map { ["visual_cast", "tts", "script_rules", "script_system", "tts_voices"].contains($0) } ?? false)
                && objectLeaves.contains(leaf)

        if treatAsJSON,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           (json is [String: Any] || json is [Any]) {
            setValue(json, at: keyPath)
        } else {
            setValue(text, at: keyPath)
        }
        isDirty = true
        saveMessage = nil
    }

    private func value(at keyPath: [String]) -> Any? {
        var current: Any? = root
        for key in keyPath {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[key]
        }
        return current
    }

    private func setValue(_ value: Any, at keyPath: [String]) {
        guard let first = keyPath.first else { return }
        if keyPath.count == 1 {
            root[first] = value
            objectWillChange.send()
            return
        }
        var copy = root
        _ = setNested(&copy, keyPath: keyPath, value: value)
        root = copy
        objectWillChange.send()
    }

    private func setNested(_ dict: inout [String: Any], keyPath: [String], value: Any) -> Bool {
        guard let head = keyPath.first else { return false }
        if keyPath.count == 1 {
            dict[head] = value
            return true
        }
        var child = dict[head] as? [String: Any] ?? [:]
        let ok = setNested(&child, keyPath: Array(keyPath.dropFirst()), value: value)
        dict[head] = child
        return ok
    }
}

/// Editable fields shown in the Prompts UI (paths into video_prompts.json).
enum VideoPromptField: String, CaseIterable, Identifiable, Hashable {
    case scriptRulesEN
    case scriptRulesKO
    case scriptRulesES
    case scriptSystemEN
    case scriptSystemKO
    case scriptSystemES
    case clipDecision
    case clipDecisionSystem
    case clipDetail
    case clipDetailSystem
    case singleClip
    case customClipUser
    case customClipSystem
    case singleClipSystem
    case scriptVerification
    case scriptVerificationSystem
    case scriptLineRewrite
    case scriptLineRewriteHook
    case scriptLineRewriteBody
    case castBibleTemplate
    case visualCastEN
    case visualCastKO
    case visualCastES
    case signs
    case explain
    case ttsEN
    case ttsKO
    case ttsES
    case ttsVoices
    case clipDurations

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scriptRulesEN: return "Script rules (EN)"
        case .scriptRulesKO: return "Script rules (KO)"
        case .scriptRulesES: return "Script rules (ES)"
        case .scriptSystemEN: return "Script system (EN)"
        case .scriptSystemKO: return "Script system (KO)"
        case .scriptSystemES: return "Script system (ES)"
        case .clipDecision: return "Clip decision prompt"
        case .clipDecisionSystem: return "Clip decision system"
        case .clipDetail: return "Clip detail JSON instruction"
        case .clipDetailSystem: return "Clip detail system"
        case .singleClip: return "Single clip fallback prompt"
        case .customClipUser: return "Custom clip user prompt"
        case .customClipSystem: return "Custom clip system"
        case .singleClipSystem: return "Single clip system"
        case .scriptVerification: return "Script verification prompt"
        case .scriptVerificationSystem: return "Script verification system"
        case .scriptLineRewrite: return "Script line rewrite prompt"
        case .scriptLineRewriteHook: return "Rewrite system (CASE)"
        case .scriptLineRewriteBody: return "Rewrite system (WHAT MATTERS/ACTION/…)"
        case .castBibleTemplate: return "Cast bible template"
        case .visualCastEN: return "Visual cast (EN)"
        case .visualCastKO: return "Visual cast (KO)"
        case .visualCastES: return "Visual cast (ES)"
        case .signs: return "Signs clip templates"
        case .explain: return "Explain clip templates"
        case .ttsEN: return "TTS (EN)"
        case .ttsKO: return "TTS (KO)"
        case .ttsES: return "TTS (ES)"
        case .ttsVoices: return "TTS voices"
        case .clipDurations: return "Clip durations"
        }
    }

    var keyPath: [String] {
        switch self {
        case .scriptRulesEN: return ["script_rules", "en"]
        case .scriptRulesKO: return ["script_rules", "ko"]
        case .scriptRulesES: return ["script_rules", "es"]
        case .scriptSystemEN: return ["script_system", "en"]
        case .scriptSystemKO: return ["script_system", "ko"]
        case .scriptSystemES: return ["script_system", "es"]
        case .clipDecision: return ["clip_decision_prompt"]
        case .clipDecisionSystem: return ["clip_decision_system"]
        case .clipDetail: return ["clip_detail_json_instruction"]
        case .clipDetailSystem: return ["clip_detail_system"]
        case .singleClip: return ["single_clip_prompt"]
        case .customClipUser: return ["custom_clip_user"]
        case .customClipSystem: return ["custom_clip_system"]
        case .singleClipSystem: return ["single_clip_system"]
        case .scriptVerification: return ["script_verification_prompt"]
        case .scriptVerificationSystem: return ["script_verification_system"]
        case .scriptLineRewrite: return ["script_line_rewrite_prompt"]
        case .scriptLineRewriteHook: return ["script_line_rewrite_system_hook"]
        case .scriptLineRewriteBody: return ["script_line_rewrite_system_body"]
        case .castBibleTemplate: return ["cast_bible_template"]
        case .visualCastEN: return ["visual_cast", "en"]
        case .visualCastKO: return ["visual_cast", "ko"]
        case .visualCastES: return ["visual_cast", "es"]
        case .signs: return ["signs"]
        case .explain: return ["explain"]
        case .ttsEN: return ["tts", "en"]
        case .ttsKO: return ["tts", "ko"]
        case .ttsES: return ["tts", "es"]
        case .ttsVoices: return ["tts_voices"]
        case .clipDurations: return ["clip_durations"]
        }
    }
}
