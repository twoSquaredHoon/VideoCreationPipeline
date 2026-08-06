import AppKit
import SwiftUI

struct VoiceoverView: View {
    @EnvironmentObject private var store: ProjectStore
    let project: VideoProject

    @State private var localError: String?

    private var current: VideoProject {
        store.projects.first(where: { $0.id == project.id }) ?? project
    }

    private var speechText: String {
        let url = current.speechURL
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private var metaText: String {
        let url = current.voiceoverMetaURL
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        let audio = obj["audio_seconds"] as? Double ?? 0
        let video = obj["video_seconds"] as? Double ?? 0
        let pace = obj["pace"] as? String ?? "auto"
        return String(format: "Audio: %.1fs · Video: %.0fs · Pace: %@", audio, video, pace)
    }

    private var voiceoverFileExists: Bool {
        FileManager.default.fileExists(atPath: current.voiceoverURL.path)
    }

    private var isGenerating: Bool {
        store.pipeline.isRunning && store.pipeline.runningStep == .generateVoiceover
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    Task { await regenerateVoiceover() }
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating…")
                    } else {
                        Label(
                            current.hasVoiceover || voiceoverFileExists
                                ? "Regenerate voiceover"
                                : "Generate voiceover",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!current.hasScript || store.pipeline.isRunning)

                if voiceoverFileExists {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([current.voiceoverURL])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }

            if let localError {
                Text(localError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !current.hasScript {
                ContentUnavailableView(
                    "Script needed",
                    systemImage: "doc.text",
                    description: Text("Generate a script before creating voiceover.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if current.hasVoiceover {
                MacAVPlayerView(url: current.voiceoverURL)
                    .frame(height: 48)
                    .id(current.voiceoverURL.path + "-\(voiceoverRevision)")

                if !metaText.isEmpty {
                    Text(metaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                spokenScriptSection
            } else if voiceoverFileExists {
                Label(
                    "voiceover.wav looks invalid or too small. Regenerate to replace it.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

                spokenScriptSection
            } else {
                ContentUnavailableView(
                    "No voiceover yet",
                    systemImage: "waveform",
                    description: Text("Generate voiceover from the script (clip lengths used for pacing when available).")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var spokenScriptSection: some View {
        Group {
            Text("Spoken script")
                .font(.headline)

            ScrollView {
                Text(speechText.isEmpty ? current.loadScript() : speechText)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Bumps when the wav is replaced so the player reloads.
    private var voiceoverRevision: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: current.voiceoverURL.path)
        let modified = attrs?[.modificationDate] as? Date
        let size = attrs?[.size] as? Int ?? 0
        return "\(modified?.timeIntervalSince1970 ?? 0)-\(size)"
    }

    private func regenerateVoiceover() async {
        localError = nil
        do {
            try await store.runWorkflowStep(current, step: .generateVoiceover)
            store.scheduleRefreshProjects(autoSelect: false)
        } catch {
            localError = error.localizedDescription
        }
    }
}
