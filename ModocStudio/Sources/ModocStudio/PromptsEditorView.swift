import SwiftUI

struct PromptsEditorView: View {
    @EnvironmentObject private var store: ProjectStore
    @StateObject private var prompts = VideoPromptsStore()
    @State private var selected: VideoPromptField = .scriptRulesEN
    @State private var editorText = ""
    @State private var suppressDirty = false
    @State private var showDetailOnNarrow = false

    var body: some View {
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < 760

            if isNarrow {
                narrowLayout
            } else {
                wideLayout(width: geometry.size.width)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            prompts.reload()
            loadSelected(resetDirty: true)
        }
        .onChange(of: selected) { _, _ in
            loadSelected(resetDirty: false)
            showDetailOnNarrow = true
        }
    }

    private var narrowLayout: some View {
        Group {
            if showDetailOnNarrow {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showDetailOnNarrow = false
                        } label: {
                            Label("Prompts", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    Divider()
                    detailPanel
                }
            } else {
                catalogPanel
            }
        }
    }

    private func wideLayout(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            catalogPanel
                .frame(width: min(340, max(220, width * 0.32)))
            Divider()
            detailPanel
                .frame(minWidth: 0, maxWidth: .infinity)
        }
    }

    private var catalogPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompts")
                        .font(.largeTitle.bold())
                    Text("Edit video-creation prompts and cast presets. Changes save to config/video_prompts.json.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt fields")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach(VideoPromptField.allCases) { field in
                            PromptFieldCard(
                                title: field.title,
                                isSelected: selected == field
                            ) {
                                selected = field
                                showDetailOnNarrow = true
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selected.title)
                    .font(.title2.bold())
                    .lineLimit(2)
                Spacer()
                if prompts.isDirty {
                    Text("Unsaved changes")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
                Button("Reload") {
                    loadSelected(resetDirty: true)
                }
                Button("Save") {
                    prompts.setStringValue(editorText, for: selected.keyPath)
                    prompts.save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!prompts.isDirty)
            }

            Text("File: \(VideoPromptsStore.configURL.path)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let err = prompts.loadError {
                Text(err)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            if let msg = prompts.saveMessage {
                Text(msg)
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            TextEditor(text: $editorText)
                .font(.system(.body, design: .monospaced))
                .onChange(of: editorText) { _, newValue in
                    guard !suppressDirty else { return }
                    prompts.setStringValue(newValue, for: selected.keyPath)
                }

            Text(
                "Placeholders like {cast_bible}, {speech_text}, {pace_hint}, {target_seconds}, "
                    + "{visual}, {child}, {parent}, {seconds}, {bullet} must stay if the pipeline uses them."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func loadSelected(resetDirty: Bool) {
        if resetDirty {
            prompts.reload()
        }
        suppressDirty = true
        editorText = prompts.stringValue(for: selected.keyPath)
        suppressDirty = false
        if resetDirty {
            prompts.isDirty = false
            prompts.saveMessage = nil
        }
    }
}

private struct PromptFieldCard: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
