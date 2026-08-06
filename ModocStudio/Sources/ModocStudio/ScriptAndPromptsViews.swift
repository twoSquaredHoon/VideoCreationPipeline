import SwiftUI

struct ScriptReviewView: View {
    @EnvironmentObject private var store: ProjectStore
    let project: VideoProject
    let script: String
    let clips: [ClipRecord]

    @State private var selectedLineIDs: Set<String> = []
    @State private var isCreating = false
    @State private var actionError: String?
    @State private var lastCreatedClipID: String?
    @State private var confirmVideo = false

    private var lines: [ScriptLine] { ScriptParser.parse(script) }

    private var selectedLines: [ScriptLine] {
        lines.filter { selectedLineIDs.contains($0.id) }
    }

    private var current: VideoProject {
        store.selectedProject ?? project
    }

    var body: some View {
        VStack(spacing: 0) {
            if script.isEmpty {
                ContentUnavailableView(
                    "No script yet",
                    systemImage: "doc.text",
                    description: Text("Generate a script from the Workflow tab.")
                )
            } else {
                scriptToolbar
                Divider()

                if lines.isEmpty {
                    ScrollView {
                        Text(script)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    selectionToolbar
                    Divider()
                    scriptList
                }
            }
        }
        .alert("Could not create clip", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
        .confirmationDialog(
            "Generate Veo video for this clip?",
            isPresented: $confirmVideo,
            titleVisibility: .visible
        ) {
            Button("Prompt + video (Veo, paid)") {
                Task { await createClip(generateVideo: true) }
            }
            Button("Prompt only (free)") {
                Task { await createClip(generateVideo: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(selectedLines.count) line(s) selected. Prompt-only adds the clip to Clips; you can generate video later.")
        }
    }

    private var scriptToolbar: some View {
        HStack(spacing: 12) {
            Text("Select lines to create custom clips")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                do {
                    try store.revealScriptPrompts(for: current)
                    actionError = nil
                } catch {
                    actionError = error.localizedDescription
                }
            } label: {
                Label("Open script_prompts.txt", systemImage: "folder")
            }
            .help("Show script_prompts.txt in Finder (blog + script + clip prompts)")
            .disabled(!current.hasScript && !current.hasClipsJSON)

            if isCreating || store.pipeline.isRunning {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Text("\(selectedLineIDs.count) of \(lines.count) lines selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !selectedLineIDs.isEmpty {
                Button("Clear") { selectedLineIDs.removeAll() }
                    .buttonStyle(.borderless)
            }

            Spacer()

            if isCreating || store.pipeline.isRunning {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                confirmVideo = true
            } label: {
                Label("Create clip from selection", systemImage: "film.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedLineIDs.isEmpty || isCreating || store.pipeline.isRunning)

            if let clipID = lastCreatedClipID {
                Text("Created \(clipID)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var scriptList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedSections, id: \.section) { group in
                    sectionBlock(group)
                }
            }
            .padding()
        }
    }

    private struct SectionGroup {
        let section: ScriptSection
        let lines: [ScriptLine]
    }

    private var groupedSections: [SectionGroup] {
        var order: [ScriptSection] = []
        var buckets: [ScriptSection: [ScriptLine]] = [:]
        for line in lines {
            if buckets[line.section] == nil {
                order.append(line.section)
                buckets[line.section] = []
            }
            buckets[line.section]?.append(line)
        }
        return order.map { SectionGroup(section: $0, lines: buckets[$0] ?? []) }
    }

    @ViewBuilder
    private func sectionBlock(_ group: SectionGroup) -> some View {
        Text(group.section.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 4)

        ForEach(group.lines) { line in
            lineRow(line)
        }
    }

    private func lineRow(_ line: ScriptLine) -> some View {
        let isSelected = selectedLineIDs.contains(line.id)
        let linkedClips = ScriptParser.clipIDs(for: line, in: clips)

        return Button {
            toggleSelection(line.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.body)

                Text(line.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !linkedClips.isEmpty {
                    Image(systemName: "film.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .help("Clip: \(linkedClips.joined(separator: ", "))")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreating || store.pipeline.isRunning)
    }

    private func toggleSelection(_ id: String) {
        if selectedLineIDs.contains(id) {
            selectedLineIDs.remove(id)
        } else {
            selectedLineIDs.insert(id)
        }
    }

    @MainActor
    private func createClip(generateVideo: Bool) async {
        isCreating = true
        defer { isCreating = false }

        let texts = selectedLines.map(\.text)
        do {
            let clipID = try await store.createCustomClip(
                current,
                lines: texts,
                generateVideo: generateVideo
            )
            lastCreatedClipID = clipID
            selectedLineIDs.removeAll()
            store.refreshProjects()
        } catch {
            actionError = error.localizedDescription
        }
    }
}

struct PromptsView: View {
    @EnvironmentObject private var store: ProjectStore
    let project: VideoProject
    let clips: [ClipRecord]
    var onSaved: (() -> Void)?

    @State private var selection: PromptSection = .detailed
    @State private var selectedClipID: String?
    @State private var draftClips: [String: ClipRecord] = [:]
    @State private var detailedText = ""
    @State private var veoText = ""
    @State private var decisionsText = ""
    @State private var isDirty = false
    @State private var suppressDirty = false
    @State private var saveError: String?
    @State private var saveMessage: String?

    enum PromptSection: String, CaseIterable, Identifiable {
        case decisions = "Decisions"
        case detailed = "Clip prompts"

        var id: String { rawValue }
    }

    private var current: VideoProject {
        store.projects.first { $0.id == project.id } ?? project
    }

    private var displayClips: [ClipRecord] {
        clips.map { draftClips[$0.id] ?? $0 }
    }

    private var selectedClip: ClipRecord? {
        guard let id = selectedClipID else { return displayClips.first }
        return displayClips.first { $0.id == id } ?? displayClips.first
    }

    var body: some View {
        Group {
            if clips.isEmpty && current.loadDecisions().isEmpty {
                ContentUnavailableView(
                    "No clip prompts yet",
                    systemImage: "text.alignleft",
                    description: Text("Generate clip prompts from the Workflow tab, then edit each clip’s Veo prompt here.")
                )
            } else {
                VStack(spacing: 0) {
                    toolbar
                    Divider()
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { reloadFromDisk() }
        .onChange(of: clips.map(\.id).joined(separator: ",")) { _, _ in
            reloadFromDisk()
        }
        .onChange(of: selectedClipID) { oldID, _ in
            if let oldID { commitEditorToDraft(clipID: oldID) }
            loadSelectedClipIntoEditors()
        }
        .onChange(of: selection) { oldValue, newValue in
            if oldValue == .detailed, let id = selectedClipID {
                commitEditorToDraft(clipID: id)
            }
            if newValue == .decisions {
                suppressDirty = true
                if decisionsText.isEmpty {
                    decisionsText = current.loadDecisions()
                }
                suppressDirty = false
            } else {
                loadSelectedClipIntoEditors()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Section", selection: $selection) {
                ForEach(PromptSection.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)

            if selection == .detailed, let clip = selectedClip {
                Text(clip.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer()

            Button("Copy script prompts") {
                do {
                    try store.copyScriptPrompts(for: current)
                    saveMessage = "Copied script_prompts.txt"
                    saveError = nil
                } catch {
                    saveError = error.localizedDescription
                }
            }
            .help("script_prompts.txt — blog + script + clip prompts")

            if isDirty {
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let saveMessage {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Button("Reload") {
                reloadFromDisk()
            }
            .disabled(store.pipeline.isRunning)

            Button("Save") {
                saveEdits()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isDirty || store.pipeline.isRunning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .decisions:
            TextEditor(text: $decisionsText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .onChange(of: decisionsText) { _, _ in
                    guard !suppressDirty else { return }
                    isDirty = true
                    saveMessage = nil
                }
        case .detailed:
            if clips.isEmpty {
                ContentUnavailableView(
                    "No clips.json yet",
                    systemImage: "film",
                    description: Text("Generate clip prompts first.")
                )
            } else {
                HSplitView {
                    clipList
                        .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
                    clipEditors
                        .frame(minWidth: 320)
                }
            }
        }
    }

    private var clipList: some View {
        List(selection: $selectedClipID) {
            ForEach(displayClips) { clip in
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.label)
                        .font(.subheadline.weight(.semibold))
                    Text(clip.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let line = clip.scriptLine, !line.isEmpty {
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .tag(clip.id)
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
    }

    private var clipEditors: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let line = selectedClip?.scriptLine, !line.isEmpty {
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            Text("Detailed prompt (used for video generation)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $detailedText)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 120)
                .onChange(of: detailedText) { _, newValue in
                    guard !suppressDirty else { return }
                    isDirty = true
                    saveMessage = nil
                    suppressDirty = true
                    veoText = newValue
                    suppressDirty = false
                    if var clip = selectedClip {
                        clip.detailedPrompt = newValue
                        // Keep Veo prompt in sync so regenerate uses this fix.
                        clip.veoPrompt = newValue
                        draftClips[clip.id] = clip
                    }
                }

            Text("Veo prompt (kept in sync with detailed — also sent to video)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $veoText)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 160)
                .onChange(of: veoText) { _, newValue in
                    guard !suppressDirty else { return }
                    isDirty = true
                    saveMessage = nil
                    if var clip = selectedClip {
                        clip.veoPrompt = newValue
                        draftClips[clip.id] = clip
                    }
                }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func reloadFromDisk() {
        saveError = nil
        saveMessage = nil
        suppressDirty = true
        decisionsText = current.loadDecisions()
        draftClips = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        if selectedClipID == nil || !clips.contains(where: { $0.id == selectedClipID }) {
            selectedClipID = clips.first?.id
        }
        loadSelectedClipIntoEditors()
        suppressDirty = false
        isDirty = false
    }

    private func loadSelectedClipIntoEditors() {
        suppressDirty = true
        if let clip = selectedClip {
            detailedText = clip.detailedPrompt ?? ""
            veoText = clip.veoPrompt ?? ""
        } else {
            detailedText = ""
            veoText = ""
        }
        suppressDirty = false
    }

    private func commitEditorToDraft(clipID: String) {
        guard var clip = draftClips[clipID] ?? clips.first(where: { $0.id == clipID }) else { return }
        clip.detailedPrompt = detailedText
        // Detailed is the video prompt source of truth when editing.
        clip.veoPrompt = detailedText.isEmpty ? veoText : detailedText
        draftClips[clipID] = clip
    }

    private func saveEdits() {
        saveError = nil
        saveMessage = nil
        do {
            if selection == .detailed, let id = selectedClipID {
                commitEditorToDraft(clipID: id)
            }
            if selection == .decisions {
                try decisionsText.write(to: current.decisionsURL, atomically: true, encoding: .utf8)
            } else {
                var updated = current.loadClips()
                for i in updated.indices {
                    if let draft = draftClips[updated[i].id] {
                        let detailed = draft.detailedPrompt ?? ""
                        updated[i].detailedPrompt = detailed
                        // Apply detailed → video prompt so regenerate uses the fix.
                        updated[i].veoPrompt = detailed.isEmpty
                            ? (draft.veoPrompt ?? "")
                            : detailed
                    }
                }
                try current.saveClips(updated)
                if let id = selectedClipID, let saved = updated.first(where: { $0.id == id }) {
                    suppressDirty = true
                    detailedText = saved.detailedPrompt ?? ""
                    veoText = saved.veoPrompt ?? ""
                    suppressDirty = false
                }
            }
            isDirty = false
            saveMessage = "Saved — detailed prompt applied to video"
            onSaved?()
            store.scheduleRefreshProjects(autoSelect: false, delayMs: 0)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

struct LogView: View {
    let log: String

    var body: some View {
        ScrollView {
            Text(log.isEmpty ? "No log output yet." : log)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
