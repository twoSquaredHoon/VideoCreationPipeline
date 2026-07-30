import SwiftUI

struct BrowseProjectsView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var showDetailOnNarrow = false
    @State private var isDetailOpen = true
    @State private var isCatalogOpen = true

    private var dateFolders: [ProjectBatchFolder] {
        store.ensureTodayInBatchFolders(store.batchFolders())
    }

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
            if store.browseSelectedDateFolder == nil {
                store.browseSelectedDateFolder = dateFolders.first?.id
            }
            store.scheduleRefreshProjects(autoSelect: false)
            if store.selectedProject != nil {
                isDetailOpen = true
            }
        }
        .onChange(of: store.selectedProjectID) { _, newValue in
            if newValue != nil {
                showDetailOnNarrow = true
                isDetailOpen = true
            }
        }
    }

    private var narrowLayout: some View {
        Group {
            if showDetailOnNarrow, store.selectedProject != nil {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            showDetailOnNarrow = false
                        } label: {
                            Label("Projects", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Button {
                            showDetailOnNarrow = false
                            store.selectedProjectID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Close project")
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
            if isCatalogOpen {
                VStack(spacing: 0) {
                    HStack {
                        Text("Projects")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isDetailOpen {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isCatalogOpen = false
                                }
                            } label: {
                                Image(systemName: "sidebar.left")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Collapse project list")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    Divider()
                    catalogPanel
                }
                .frame(
                    width: isDetailOpen
                        ? min(340, max(220, width * 0.32))
                        : nil
                )
                .frame(maxWidth: isDetailOpen ? nil : .infinity)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCatalogOpen = true
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "sidebar.left")
                            .font(.title3)
                        Text("List")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
                    .frame(width: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show project list")
                .background(Color(nsColor: .windowBackgroundColor))
            }

            if isDetailOpen {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        if !isCatalogOpen {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isCatalogOpen = true
                                }
                            } label: {
                                Label("Projects", systemImage: "sidebar.left")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Text("Working project")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            isDetailOpen = false
                            isCatalogOpen = true
                        } label: {
                            Label("Close", systemImage: "sidebar.trailing")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Hide the working project panel")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    Divider()
                    detailPanel
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            } else if store.selectedProject != nil {
                Divider()
                Button {
                    isDetailOpen = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "sidebar.trailing")
                            .font(.title2)
                        Text("Open")
                            .font(.caption)
                        Text("project")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
                    .frame(width: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show the working project panel")
            }
        }
    }

    private var catalogPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Browse Projects")
                        .font(.largeTitle.bold())
                    Text("Pick a date (or Other projects), then open a project to edit and run pipeline steps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if dateFolders.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "calendar",
                        description: Text("Run a daily batch or single video from Run Pipeline.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    datePickerRow
                    if let dateID = store.browseSelectedDateFolder {
                        dateProjectsContent(dateFolderID: dateID)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var datePickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(dateFolders) { folder in
                        BrowseDateChip(
                            folder: folder,
                            isSelected: store.browseSelectedDateFolder == folder.id
                        ) {
                            store.browseSelectedDateFolder = folder.id
                            if folder.id != ProjectBatchFolder.legacyID {
                                let inFolder = store.projects(inBatchFolder: folder.id)
                                if !inFolder.contains(where: { $0.id == store.selectedProjectID }) {
                                    store.selectedProjectID = inFolder.first?.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dateProjectsContent(dateFolderID: String) -> some View {
        if dateFolderID == ProjectBatchFolder.legacyID {
            projectSection(title: "Other projects", projects: store.projects(inBatchFolder: dateFolderID))
        } else {
            let languages = store.languageFolders(in: dateFolderID)
            if languages.isEmpty {
                batchEmptyState(for: dateFolderID)
            } else {
                ForEach(languages) { lang in
                    projectSection(
                        title: lang.displayTitle,
                        projects: store.projects(inBatchFolder: dateFolderID, languageFolder: lang.id)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func batchEmptyState(for dateFolderID: String) -> some View {
        let pending = store.batchPendingURLCount(for: dateFolderID)
        let needsResume = store.batchNeedsResume(for: dateFolderID)

        VStack(alignment: .leading, spacing: 8) {
            Text("No projects for this date yet.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if pending > 0 {
                Text("\(pending) URL\(pending == 1 ? "" : "s") in urls.txt — a batch was started but never created project folders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if needsResume {
                    Text("Nothing is running now. Resume from Run Pipeline or run ./resume-batch.sh \(dateFolderID) in Terminal.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func projectSection(title: String, projects: [VideoProject]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            if projects.isEmpty {
                Text("No projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(projects) { project in
                        BrowseProjectCard(
                            project: project,
                            isSelected: store.selectedProjectID == project.id
                        ) {
                            store.selectedProjectID = project.id
                            showDetailOnNarrow = true
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let project = store.selectedProject {
            ProjectDetailView(project: project, tabSet: .workspace)
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Select a project",
                systemImage: "film.stack",
                description: Text("Choose a project to edit scripts and run pipeline steps.")
            )
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

private struct BrowseDateChip: View {
    let folder: ProjectBatchFolder
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)
                Text(folder.isLegacy ? "Standalone" : folder.id)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                Text("\(folder.projectCount) project\(folder.projectCount == 1 ? "" : "s")")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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

private struct BrowseProjectCard: View {
    let project: VideoProject
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.manifest.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        PhaseBadge(phase: project.manifest.phase)
                        LanguageBadge(language: project.manifest.language)
                    }
                }
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
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
