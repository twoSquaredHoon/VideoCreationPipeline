import AppKit
import SwiftUI

/// Article summary (case sheet) — replaces the old script-vs-article check UI.
struct CaseSheetView: View {
    @EnvironmentObject private var store: ProjectStore
    let project: VideoProject

    @State private var caseSheetText = ""
    @State private var actionError: String?
    @State private var isRunning = false

    private var current: VideoProject {
        store.projects.first(where: { $0.id == project.id }) ?? project
    }

    private var bodyText: String {
        caseSheetText
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("#") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pipelineRunningThisStep: Bool {
        store.pipeline.isRunning && store.pipeline.runningStep == .extractCaseSheet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Divider()

            if isRunning || pipelineRunningThisStep {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Summarizing important facts from the article…")
                        .foregroundStyle(.secondary)
                    LogView(log: store.pipeline.logText)
                        .frame(maxHeight: 220)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bodyText.isEmpty {
                ContentUnavailableView {
                    Label("No article summary yet", systemImage: "list.bullet.clipboard")
                } description: {
                    Text("Medical gate before scripting: age, timelines, meds, one clinical question, same-day action, and ER triggers — without merging separate facts.")
                } actions: {
                    Button("Build article summary") {
                        Task { await buildSummary() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(current.manifest.blogURL.isEmpty || store.pipeline.isRunning)
                }
            } else {
                if let actionError {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                ScrollView {
                    Text(bodyText)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { reload() }
        .onChange(of: current.id) { _, _ in reload() }
        .onChange(of: store.pipeline.isRunning) { _, running in
            if !running { reload() }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Label("Article summary", systemImage: "list.bullet.clipboard")
                .font(.subheadline.weight(.semibold))

            if current.hasCaseSheet {
                Text("case_sheet.txt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if current.hasCaseSheet {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([current.caseSheetURL])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .disabled(store.pipeline.isRunning)
            }

            Button {
                Task { await buildSummary() }
            } label: {
                Label(
                    current.hasCaseSheet ? "Rebuild summary" : "Build article summary",
                    systemImage: "arrow.clockwise"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(current.manifest.blogURL.isEmpty || store.pipeline.isRunning || isRunning)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func reload() {
        caseSheetText = current.loadCaseSheet()
    }

    @MainActor
    private func buildSummary() async {
        actionError = nil
        isRunning = true
        defer { isRunning = false }
        do {
            try await store.extractCaseSheet(current)
            reload()
            store.scheduleRefreshProjects(autoSelect: false)
        } catch {
            actionError = error.localizedDescription
        }
    }
}
