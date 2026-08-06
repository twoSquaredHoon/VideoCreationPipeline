import SwiftUI

struct ClipsGalleryView: View {
    @EnvironmentObject private var store: ProjectStore
    let project: VideoProject
    let clips: [ClipRecord]
    @Binding var selectedClipID: String?
    var onPromptsSaved: (() -> Void)?

    @State private var regenError: String?
    @State private var isRegenerating = false
    @State private var playerKey = UUID()
    @State private var confirmRegenerateAll = false
    @State private var isClipSidebarOpen = true

    @State private var detailedText = ""
    @State private var veoText = ""
    @State private var isPromptDirty = false
    @State private var suppressPromptDirty = false
    @State private var promptSaveError: String?
    @State private var promptSaveMessage: String?

    private var current: VideoProject {
        store.projects.first { $0.id == project.id } ?? project
    }

    private var videoStatus: (done: Int, total: Int) {
        current.videoStatus(for: clips)
    }

    private var selectedClip: ClipRecord? {
        guard let id = selectedClipID else { return nil }
        return clips.first { $0.id == id }
    }

    var body: some View {
        Group {
            if clips.isEmpty {
                ContentUnavailableView(
                    "No clips yet",
                    systemImage: "film",
                    description: Text("Generate clip prompts and videos from the Workflow tab.")
                )
            } else {
                VStack(spacing: 0) {
                    clipsToolbar
                    Divider()
                    HStack(spacing: 0) {
                        if isClipSidebarOpen {
                            clipList
                                .frame(minWidth: 160, idealWidth: 200, maxWidth: 260)
                            Divider()
                        } else {
                            collapsedClipSidebar
                            Divider()
                        }

                        HSplitView {
                            promptPanel
                                .frame(minWidth: 240, idealWidth: 360)
                            videoPanel
                                .frame(minWidth: 260, idealWidth: 360)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: store.pipeline.isRunning) { _, running in
            if !running { playerKey = UUID() }
        }
        .onAppear {
            if selectedClipID == nil {
                selectedClipID = clips.first?.id
            }
            loadPromptEditors()
        }
        .onChange(of: selectedClipID) { _, _ in
            loadPromptEditors()
        }
        .onChange(of: clips.map(\.id).joined(separator: ",")) { _, _ in
            if selectedClipID == nil || !clips.contains(where: { $0.id == selectedClipID }) {
                selectedClipID = clips.first?.id
            }
            loadPromptEditors()
        }
    }

    private var clipsToolbar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isClipSidebarOpen.toggle()
                }
            } label: {
                Label(
                    isClipSidebarOpen ? "Hide clips" : "Show clips",
                    systemImage: isClipSidebarOpen ? "sidebar.left" : "sidebar.left"
                )
            }
            .help(isClipSidebarOpen ? "Collapse clip list" : "Expand clip list")

            Text("\(videoStatus.done)/\(videoStatus.total) clips generated")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isRegeneratingAllClips {
                ProgressView()
                    .controlSize(.small)
                Text("Regenerating all clips…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                confirmRegenerateAll = true
            } label: {
                Label("Regenerate all clips", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!current.hasClipsJSON || store.pipeline.isRunning || isRegenerating)
            .confirmationDialog(
                "Regenerate all \(clips.count) clips?",
                isPresented: $confirmRegenerateAll,
                titleVisibility: .visible
            ) {
                Button("Regenerate all (\(clips.count) clips, Veo paid)", role: .destructive) {
                    Task { await regenerateAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes every existing clip video and generates them again from the current prompts.")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var collapsedClipSidebar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isClipSidebarOpen = true
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                    .font(.title3)
                Text("Clips")
                    .font(.caption2)
                if let clip = selectedClip {
                    Text(clip.id)
                        .font(.system(size: 9, design: .monospaced))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(.secondary)
            .frame(maxHeight: .infinity)
            .frame(width: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show clip list")
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var clipList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Clips")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isClipSidebarOpen = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .help("Collapse clip list")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            List(clips, selection: $selectedClipID) { clip in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clip.label)
                            .font(.subheadline.weight(.medium))
                        Text(clip.id)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isRegeneratingAllClips {
                        ProgressView()
                            .controlSize(.mini)
                    } else if hasVideo(clip.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Image(systemName: "circle.dashed")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                    }
                }
                .tag(clip.id)
            }
            .listStyle(.sidebar)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Prompts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let clip = selectedClip {
                    Text(clip.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isPromptDirty {
                    Text("Unsaved")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if let promptSaveMessage {
                    Text(promptSaveMessage)
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if let promptSaveError {
                    Text(promptSaveError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
                Button("Reload") {
                    loadPromptEditors()
                }
                .disabled(store.pipeline.isRunning)
                Button("Save") {
                    savePromptEdits()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isPromptDirty || store.pipeline.isRunning || selectedClip == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            if selectedClip != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let line = selectedClip?.scriptLine, !line.isEmpty {
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Text("Detailed prompt (used for video generation)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $detailedText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 100)
                        .onChange(of: detailedText) { _, newValue in
                            guard !suppressPromptDirty else { return }
                            isPromptDirty = true
                            promptSaveMessage = nil
                            // Keep Veo field in sync so regenerate uses this fix.
                            suppressPromptDirty = true
                            veoText = newValue
                            suppressPromptDirty = false
                        }

                    Text("Veo prompt (kept in sync with detailed)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $veoText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 140)
                        .onChange(of: veoText) { _, _ in
                            guard !suppressPromptDirty else { return }
                            isPromptDirty = true
                            promptSaveMessage = nil
                        }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView("Select a clip", systemImage: "text.alignleft")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var videoPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Video")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let id = selectedClipID {
                    regenerateButton(for: id)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            if let regenError {
                Text(regenError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            if let id = selectedClipID, let clip = selectedClip {
                previewContent(for: clip, id: id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Select a clip", systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func previewContent(for clip: ClipRecord, id: String) -> some View {
        if isRegeneratingClip(id) {
            VStack(spacing: 12) {
                ProgressView()
                Text(regeneratingMessage(for: id))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if hasVideo(id), let url = current.resolvedVideoURL(for: id) {
            MacAVPlayerView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .id(playerKey)
        } else {
            ContentUnavailableView(
                "Not generated",
                systemImage: "video.slash",
                description: Text("Tap Regenerate clip to create this video.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func regenerateButton(for clipId: String) -> some View {
        Button {
            Task { await regenerate(clipId: clipId) }
        } label: {
            Label("Regenerate", systemImage: "arrow.clockwise")
        }
        .disabled(!current.hasClipsJSON || store.pipeline.isRunning || isRegenerating)
    }

    private func loadPromptEditors() {
        promptSaveError = nil
        promptSaveMessage = nil
        suppressPromptDirty = true
        detailedText = selectedClip?.detailedPrompt ?? ""
        veoText = selectedClip?.veoPrompt ?? ""
        suppressPromptDirty = false
        isPromptDirty = false
    }

    private func savePromptEdits() {
        promptSaveError = nil
        promptSaveMessage = nil
        guard let clipID = selectedClipID else { return }
        do {
            var updated = current.loadClips()
            guard let idx = updated.firstIndex(where: { $0.id == clipID }) else {
                promptSaveError = "Clip not found"
                return
            }
            updated[idx].detailedPrompt = detailedText
            // Apply detailed → video prompt so regenerate uses the fix.
            let videoPrompt = detailedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? veoText
                : detailedText
            updated[idx].veoPrompt = videoPrompt
            try current.saveClips(updated)
            suppressPromptDirty = true
            veoText = videoPrompt
            suppressPromptDirty = false
            isPromptDirty = false
            promptSaveMessage = "Saved — applied to video prompt"
            onPromptsSaved?()
            store.scheduleRefreshProjects(autoSelect: false, delayMs: 0)
        } catch {
            promptSaveError = error.localizedDescription
        }
    }

    private func regeneratingMessage(for clipId: String) -> String {
        if isRegeneratingAllClips {
            return "Regenerating all clips… (\(clipId) may be in queue)"
        }
        return "Regenerating \(clipId)… (Veo, paid)"
    }

    private var isRegeneratingAllClips: Bool {
        store.pipeline.runningStep == .regenerateAllClips
    }

    private func isRegeneratingClip(_ clipId: String) -> Bool {
        if isRegeneratingAllClips { return true }
        if case .regenerateClip(let id) = store.pipeline.runningStep {
            return id == clipId
        }
        return isRegenerating
    }

    private func regenerate(clipId: String) async {
        if isPromptDirty {
            savePromptEdits()
        }
        regenError = nil
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            try await store.runWorkflowStep(current, step: .regenerateClip(clipId))
            playerKey = UUID()
            store.refreshProjects()
            onPromptsSaved?()
        } catch {
            regenError = error.localizedDescription
        }
    }

    private func regenerateAll() async {
        if isPromptDirty {
            savePromptEdits()
        }
        regenError = nil
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            try await store.runWorkflowStep(current, step: .regenerateAllClips)
            playerKey = UUID()
            store.refreshProjects()
            onPromptsSaved?()
        } catch {
            regenError = error.localizedDescription
        }
    }

    private func hasVideo(_ clipID: String) -> Bool {
        current.hasVideo(for: clipID)
    }
}
