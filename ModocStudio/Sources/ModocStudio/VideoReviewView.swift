import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct VideoReviewView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var playerKey = UUID()
    @State private var listRefreshID = UUID()
    @State private var isDropTargeted = false

    private var inboxItems: [EndProductItem] {
        store.endProductInboxItems()
    }

    private var passedItems: [EndProductItem] {
        store.endProductPassedItems()
    }

    private var selectedItem: EndProductItem? {
        store.videoReviewSelectedItem
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < 720 {
                VStack(spacing: 0) {
                    catalogPanel
                        .frame(maxHeight: min(geometry.size.height * 0.45, 400))
                    Divider()
                    detailPanel
                        .frame(maxHeight: .infinity)
                }
            } else {
                HSplitView {
                    catalogPanel
                        .frame(minWidth: 250, idealWidth: 320, maxWidth: 400)
                    detailPanel
                        .frame(minWidth: 320)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            try? EndProducts.ensureLayout()
            store.scheduleRefreshProjects(autoSelect: false)
            store.refreshEndProductSelection()
        }
        .onChange(of: store.pipeline.isRunning) { _, running in
            if !running {
                listRefreshID = UUID()
                store.refreshEndProductSelection()
                playerKey = UUID()
            }
        }
        .id(listRefreshID)
    }

    private var catalogPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                dropZone

                HStack(spacing: 8) {
                    Button {
                        Task { await store.reviewAllInboxEndProducts() }
                    } label: {
                        Label("Review all in inbox", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.pipeline.isRunning || inboxItems.isEmpty)

                    Button {
                        store.revealEndProductsInbox()
                    } label: {
                        Label("Inbox folder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        listRefreshID = UUID()
                        store.refreshEndProductSelection()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                if !inboxItems.isEmpty {
                    section(title: "Inbox", items: inboxItems)
                }

                if !passedItems.isEmpty {
                    section(title: "Passed", items: passedItems)
                }

                if inboxItems.isEmpty && passedItems.isEmpty {
                    ContentUnavailableView(
                        "No videos yet",
                        systemImage: "film.stack",
                        description: Text("Drag a .mov or .mp4 here to import and run a medical review.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video Review")
                .font(.largeTitle.bold())
            Text("Drop exports into the inbox — each drag runs one review. Passed videos move to a date folder automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(EndProducts.inboxURL.path)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 30))
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
            Text(isDropTargeted ? "Drop to import & review" : "Drag .mp4 or .mov here")
                .font(.subheadline.weight(.semibold))
            Text("Reviews run immediately. Pass → passed/YYYY-MM-DD/")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isDropTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [8, 6])
                )
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            store.handleEndProductDrop(url, runReview: true)
            listRefreshID = UUID()
            playerKey = UUID()
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private func section(title: String, items: [EndProductItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(items) { item in
                EndProductRow(
                    item: item,
                    isSelected: store.videoReviewSelectedItemID == item.id
                ) {
                    store.videoReviewSelectedItemID = item.id
                    playerKey = UUID()
                }
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let item = selectedItem {
            EndProductDetailPanel(item: item, playerKey: $playerKey)
        } else {
            ContentUnavailableView(
                "Select a video",
                systemImage: "play.rectangle",
                description: Text("Pick from the inbox or drop a new export.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

private struct EndProductRow: View {
    let item: EndProductItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if item.location == .passed, let date = item.dateFolder {
                        Text(date)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(isSelected ? 0.35 : 0.15), in: Capsule())
                    } else {
                        Text("Inbox")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(isSelected ? 0.35 : 0.15), in: Capsule())
                    }
                    if let report = item.review {
                        Image(systemName: report.verdict.icon)
                            .font(.caption)
                            .foregroundStyle(isSelected ? Color.white : report.verdict.color)
                    }
                }
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(2)
                if let project = item.linkedProject {
                    Text(project.manifest.title)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EndProductDetailPanel: View {
    @EnvironmentObject private var store: ProjectStore
    let item: EndProductItem
    @Binding var playerKey: UUID

    @State private var actionError: String?
    @State private var showLinkSheet = false
    @State private var copiedDocument = false

    private var currentItem: EndProductItem {
        EndProducts.allItems().first { $0.id == item.id } ?? item
    }

    private var isReviewing: Bool {
        store.pipeline.isRunning && store.pipeline.runningStep == .reviewFinishedVideo
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentItem.displayName)
                            .font(.title3.bold())
                        if let project = currentItem.linkedProject {
                            Text(project.manifest.title)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No linked project — link one for script context")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if currentItem.location == .passed, let date = currentItem.dateFolder {
                            Label("Passed \(date)", systemImage: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    Spacer()
                    Button {
                        NSWorkspace.shared.selectFile(
                            currentItem.videoURL.path,
                            inFileViewerRootedAtPath: currentItem.videoURL.deletingLastPathComponent().path
                        )
                    } label: {
                        Label("Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }

                MacAVPlayerView(url: currentItem.videoURL)
                    .frame(minHeight: 300)
                    .id(playerKey)

                HStack(spacing: 8) {
                    if currentItem.location == .inbox {
                        Button {
                            Task { await store.reviewEndProduct(at: currentItem.videoURL) }
                        } label: {
                            Label("Run review", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isReviewing || store.pipeline.isRunning)
                    }

                    Button {
                        showLinkSheet = true
                    } label: {
                        Label("Link project…", systemImage: "link")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        importViaPanel()
                    } label: {
                        Label("Replace file…", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentItem.location != .inbox)
                }

                if isReviewing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Gemini is watching this video…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let actionError {
                    Text(actionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                if let report = currentItem.review {
                    reviewDocumentSection(report: report)
                    Divider()
                    VisualReviewReportView(report: report)
                } else {
                    Text("No review yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showLinkSheet) {
            EndProductImportSheet(videoURL: currentItem.videoURL, linkOnly: true) {}
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func reviewDocumentSection(report: VisualMedicalReviewReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Review document")
                .font(.headline)

            Text("Plain-text review — open, print, or copy to paste into email, Docs, Notion, etc.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    store.openReviewDocument(for: currentItem.videoURL)
                } label: {
                    Label("Open document", systemImage: "doc.text")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    store.printReviewDocument(for: currentItem.videoURL)
                } label: {
                    Label("Print", systemImage: "printer")
                }
                .buttonStyle(.bordered)

                Button {
                    store.copyReviewDocument(for: currentItem.videoURL)
                    copiedDocument = true
                } label: {
                    Label(copiedDocument ? "Copied" : "Copy all", systemImage: copiedDocument ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            if let docURL = currentItem.reviewDocumentURL {
                Text(docURL.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            if let preview = currentItem.reviewDocumentText {
                Text(preview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .contextMenu {
                        Button {
                            store.copyReviewDocument(for: currentItem.videoURL)
                            copiedDocument = true
                        } label: {
                            Label("Copy all", systemImage: "doc.on.doc")
                        }
                        Button {
                            store.printReviewDocument(for: currentItem.videoURL)
                        } label: {
                            Label("Print…", systemImage: "printer")
                        }
                        Divider()
                        Button {
                            store.openReviewDocument(for: currentItem.videoURL)
                        } label: {
                            Label("Open in TextEdit", systemImage: "doc.text")
                        }
                    }
            }
        }
        .onChange(of: currentItem.id) { _, _ in copiedDocument = false }
    }

    private func importViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try FileManager.default.removeItem(at: currentItem.videoURL)
            _ = try store.importEndProductToInbox(from: url, project: currentItem.linkedProject)
            playerKey = UUID()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
