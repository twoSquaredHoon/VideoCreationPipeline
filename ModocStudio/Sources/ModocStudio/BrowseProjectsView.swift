import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Encodes project folder paths as plain text so macOS does not treat them as file URLs.
private enum ProjectDrag {
    private static let prefix = "modoc-project:"

    static let dropTypes: [UTType] = [.utf8PlainText, .plainText, .text]

    static func encode(_ projectID: String) -> String {
        prefix + Data(projectID.utf8).base64EncodedString()
    }

    static func decode(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { return nil }
        let b64 = String(trimmed.dropFirst(prefix.count))
        guard let data = Data(base64Encoded: b64),
              let id = String(data: data, encoding: .utf8),
              !id.isEmpty else { return nil }
        return id
    }

    static func provider(forProjectID projectID: String) -> NSItemProvider {
        NSItemProvider(object: encode(projectID) as NSString)
    }

    static func loadProjectID(
        from providers: [NSItemProvider],
        completion: @escaping (String) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: {
            $0.canLoadObject(ofClass: NSString.self)
                || $0.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) else { return false }

        if provider.canLoadObject(ofClass: NSString.self) {
            _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let raw = item as? String ?? (item as? NSString) as String?,
                      let projectID = decode(raw) else { return }
                DispatchQueue.main.async { completion(projectID) }
            }
            return true
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
            guard let data,
                  let raw = String(data: data, encoding: .utf8),
                  let projectID = decode(raw) else { return }
            DispatchQueue.main.async { completion(projectID) }
        }
        return true
    }
}

struct BrowseProjectsView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var showDetailOnNarrow = false
    @State private var isDetailOpen = true
    @State private var isCatalogOpen = true
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var renameGroupID: String?
    @State private var renameGroupName = ""
    @State private var renameProjectID: String?
    @State private var renameProjectName = ""

    private var selectedGroupID: String {
        store.browseSelectedGroupID ?? ProjectGroupsFile.ungroupedID
    }

    private var selectedGroupProjects: [VideoProject] {
        store.projects(inGroup: selectedGroupID)
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
            if store.browseSelectedGroupID == nil {
                store.browseSelectedGroupID = ProjectGroupsFile.ungroupedID
            }
            store.reloadProjectGroups()
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
        .alert("New group", isPresented: $showNewGroupAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) {
                newGroupName = ""
            }
            Button("Add") {
                store.addProjectGroup(named: newGroupName)
                newGroupName = ""
            }
        } message: {
            Text("Projects can be dragged into this group from the list.")
        }
        .alert(
            "Rename group",
            isPresented: Binding(
                get: { renameGroupID != nil },
                set: { if !$0 { renameGroupID = nil } }
            )
        ) {
            TextField("Group name", text: $renameGroupName)
            Button("Cancel", role: .cancel) {
                renameGroupID = nil
                renameGroupName = ""
            }
            Button("Save") {
                if let id = renameGroupID {
                    store.renameProjectGroup(id: id, to: renameGroupName)
                }
                renameGroupID = nil
                renameGroupName = ""
            }
        }
        .alert(
            "Rename project",
            isPresented: Binding(
                get: { renameProjectID != nil },
                set: { if !$0 { renameProjectID = nil } }
            )
        ) {
            TextField("Project name", text: $renameProjectName)
            Button("Cancel", role: .cancel) {
                renameProjectID = nil
                renameProjectName = ""
            }
            Button("Save") {
                if let id = renameProjectID {
                    store.renameProject(id: id, to: renameProjectName)
                }
                renameProjectID = nil
                renameProjectName = ""
            }
        } message: {
            Text("Shown in Browse Projects and the project header. Folder name on disk stays the same.")
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
                        ? min(420, max(280, width * 0.38))
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
        HStack(spacing: 0) {
            groupsSidebar
                .frame(width: 168)
            Divider()
            projectsList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var groupsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Groups")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    newGroupName = ""
                    showNewGroupAlert = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add group")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    BrowseGroupRow(
                        title: "Ungrouped",
                        count: store.ungroupedProjects.count,
                        isSelected: selectedGroupID == ProjectGroupsFile.ungroupedID,
                        systemImage: "tray",
                        onSelect: {
                            store.selectBrowseGroup(ProjectGroupsFile.ungroupedID)
                        },
                        onDropProject: { projectID in
                            store.moveProject(projectID, toGroup: ProjectGroupsFile.ungroupedID)
                        }
                    )

                    ForEach(store.projectGroups) { group in
                        BrowseGroupRow(
                            title: group.name,
                            count: store.projects(inGroup: group.id).count,
                            isSelected: selectedGroupID == group.id,
                            systemImage: "folder",
                            onSelect: {
                                store.selectBrowseGroup(group.id)
                            },
                            onDropProject: { projectID in
                                store.moveProject(projectID, toGroup: group.id)
                            }
                        )
                        .contextMenu {
                            Button("Rename…") {
                                renameGroupID = group.id
                                renameGroupName = group.name
                            }
                            Button("Delete group", role: .destructive) {
                                store.deleteProjectGroup(id: group.id)
                            }
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var projectsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedGroupTitle)
                    .font(.headline)
                Text("Drag a project onto a group in the sidebar to organize.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if store.projects.isEmpty {
                ContentUnavailableView(
                    "No projects yet",
                    systemImage: "film.stack",
                    description: Text("Create a single video from Run Pipeline.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedGroupProjects.isEmpty {
                ContentUnavailableView(
                    selectedGroupID == ProjectGroupsFile.ungroupedID
                        ? "No ungrouped projects"
                        : "Empty group",
                    systemImage: "folder",
                    description: Text(
                        selectedGroupID == ProjectGroupsFile.ungroupedID
                            ? "All projects are in groups, or create a new project."
                            : "Drag projects here from Ungrouped or another group."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: ProjectDrag.dropTypes, isTargeted: nil) { providers in
                    ProjectDrag.loadProjectID(from: providers) { projectID in
                        store.moveProject(projectID, toGroup: selectedGroupID)
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(selectedGroupProjects) { project in
                            BrowseProjectCard(
                                project: project,
                                isSelected: store.selectedProjectID == project.id,
                                onSelect: {
                                    store.selectedProjectID = project.id
                                    showDetailOnNarrow = true
                                },
                                onRename: {
                                    renameProjectID = project.id
                                    renameProjectName = project.manifest.title
                                }
                            )
                        }
                    }
                    .padding(12)
                }
                .onDrop(of: ProjectDrag.dropTypes, isTargeted: nil) { providers in
                    ProjectDrag.loadProjectID(from: providers) { projectID in
                        store.moveProject(projectID, toGroup: selectedGroupID)
                    }
                }
            }
        }
    }

    private var selectedGroupTitle: String {
        if selectedGroupID == ProjectGroupsFile.ungroupedID {
            return "Ungrouped"
        }
        return store.projectGroups.first(where: { $0.id == selectedGroupID })?.name ?? "Group"
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

private struct BrowseGroupRow: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let systemImage: String
    let onSelect: () -> Void
    let onDropProject: (String) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(rowForeground.opacity(isSelected ? 0.95 : 1))
                    .frame(width: 14)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(rowForeground)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(rowForeground.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .allowsHitTesting(false)

            // Must sit above the label so AppKit receives the drop.
            ProjectDropCatcher(
                isTargeted: $isDropTargeted,
                onSelect: onSelect,
                onDropProject: onDropProject
            )
        }
        .frame(minHeight: 32)
    }

    private var rowForeground: Color {
        if isDropTargeted { return .primary }
        return isSelected ? .white : .primary
    }

    private var rowBackground: Color {
        if isDropTargeted { return Color.accentColor.opacity(0.28) }
        return isSelected ? Color.accentColor : Color.clear
    }
}

/// AppKit-backed drop surface so group rows accept plain-text project drags reliably.
private struct ProjectDropCatcher: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onSelect: () -> Void
    let onDropProject: (String) -> Void

    func makeNSView(context: Context) -> ProjectDropNSView {
        let view = ProjectDropNSView()
        view.onSelect = onSelect
        view.onDropProject = onDropProject
        view.onTargetedChange = { isTargeted = $0 }
        return view
    }

    func updateNSView(_ nsView: ProjectDropNSView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onDropProject = onDropProject
        nsView.onTargetedChange = { isTargeted = $0 }
    }
}

private final class ProjectDropNSView: NSView {
    var onSelect: (() -> Void)?
    var onDropProject: ((String) -> Void)?
    var onTargetedChange: ((Bool) -> Void)?

    private static let acceptedTypes: [NSPasteboard.PasteboardType] = [
        .string,
        NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier),
        NSPasteboard.PasteboardType(UTType.plainText.identifier),
        NSPasteboard.PasteboardType(UTType.text.identifier),
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(Self.acceptedTypes)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptTypes(sender) else { return [] }
        onTargetedChange?(true)
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        canAcceptTypes(sender) ? .move : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        canAcceptTypes(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange?(false)
        guard let projectID = readProjectID(from: sender) else { return false }
        onDropProject?(projectID)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    private func canAcceptTypes(_ sender: NSDraggingInfo) -> Bool {
        let available = Set(sender.draggingPasteboard.types ?? [])
        return Self.acceptedTypes.contains { available.contains($0) }
    }

    private func readProjectID(from sender: NSDraggingInfo) -> String? {
        let pb = sender.draggingPasteboard
        for type in Self.acceptedTypes {
            if let raw = pb.string(forType: type), let id = ProjectDrag.decode(raw) {
                return id
            }
        }
        if let objects = pb.readObjects(forClasses: [NSString.self], options: nil) {
            for object in objects {
                if let raw = object as? String, let id = ProjectDrag.decode(raw) {
                    return id
                }
                if let raw = object as? NSString, let id = ProjectDrag.decode(raw as String) {
                    return id
                }
            }
        }
        return nil
    }
}

private struct BrowseProjectCard: View {
    let project: VideoProject
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
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
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

                ProjectDragSource(
                    projectID: project.id,
                    title: project.manifest.title,
                    onClick: onSelect
                )
            }
            .frame(maxWidth: .infinity)

            Menu {
                Button("Rename…", action: onRename)
                Divider()
                ProjectMoveMenu(projectID: project.id)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help("Rename or move project")
            .padding(.trailing, 10)
            .padding(.top, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
    }
}

/// Writes the project id onto the pasteboard immediately so AppKit group drops can accept it.
private struct ProjectDragSource: NSViewRepresentable {
    let projectID: String
    let title: String
    let onClick: () -> Void

    func makeNSView(context: Context) -> ProjectDragNSView {
        let view = ProjectDragNSView()
        view.projectID = projectID
        view.title = title
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: ProjectDragNSView, context: Context) {
        nsView.projectID = projectID
        nsView.title = title
        nsView.onClick = onClick
    }
}

private final class ProjectDragNSView: NSView, NSDraggingSource {
    var projectID: String = ""
    var title: String = ""
    var onClick: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isDragging, let mouseDownEvent else { return }
        let start = mouseDownEvent.locationInWindow
        let current = event.locationInWindow
        let distance = hypot(current.x - start.x, current.y - start.y)
        guard distance > 4 else { return }

        isDragging = true
        let encoded = ProjectDrag.encode(projectID)
        let pbItem = NSPasteboardItem()
        pbItem.setString(encoded, forType: .string)
        pbItem.setString(encoded, forType: NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier))

        let draggingItem = NSDraggingItem(pasteboardWriter: pbItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage())
        beginDraggingSession(with: [draggingItem], event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            isDragging = false
        }
        guard !isDragging else { return }
        onClick?()
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    private func dragImage() -> NSImage {
        let label = NSTextField(labelWithString: title.isEmpty ? "Project" : title)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        label.sizeToFit()
        let padding: CGFloat = 10
        let size = NSSize(
            width: min(max(label.bounds.width + padding * 2, 80), 220),
            height: label.bounds.height + padding * 2
        )
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 8, yRadius: 8).fill()
        label.draw(
            NSRect(
                x: padding,
                y: padding,
                width: size.width - padding * 2,
                height: label.bounds.height
            )
        )
        image.unlockFocus()
        return image
    }
}

private struct ProjectMoveMenu: View {
    @EnvironmentObject private var store: ProjectStore
    let projectID: String

    var body: some View {
        Menu("Move to group") {
            Button("Ungrouped") {
                store.moveProject(projectID, toGroup: ProjectGroupsFile.ungroupedID)
            }
            ForEach(store.projectGroups) { group in
                Button(group.name) {
                    store.moveProject(projectID, toGroup: group.id)
                }
            }
        }
    }
}
