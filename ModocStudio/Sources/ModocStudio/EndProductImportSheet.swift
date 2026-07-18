import SwiftUI

struct EndProductImportSheet: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    let videoURL: URL
    var linkOnly: Bool = false
    let onDone: () -> Void

    @State private var errorMessage: String?

    private var sortedProjects: [VideoProject] {
        store.projects.sorted {
            $0.manifest.title.localizedCaseInsensitiveCompare($1.manifest.title) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(linkOnly ? "Link to project" : "Link video to project")
                .font(.title2.bold())

            Text(linkOnly
                 ? "Adds script and article-check context for medical review."
                 : "Which project is this export for?")
                .foregroundStyle(.secondary)

            Text(videoURL.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if sortedProjects.isEmpty {
                Text("No projects found. Create one in Run Pipeline first.")
                    .foregroundStyle(.orange)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sortedProjects) { project in
                            Button {
                                link(project)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(project.manifest.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(project.folderURL.lastPathComponent)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    LanguageBadge(language: project.manifest.language)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func link(_ project: VideoProject) {
        errorMessage = nil
        do {
            if linkOnly {
                try store.linkEndProduct(at: videoURL, to: project)
            } else {
                _ = try store.importEndProductToInbox(from: videoURL, project: project)
            }
            onDone()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
