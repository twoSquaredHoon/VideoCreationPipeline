import SwiftUI

struct RunPipelineHubView: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Run Pipeline")
                        .font(.largeTitle.bold())
                    Text("Create one video from a blog URL.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                creationCard(
                    title: "Single Video",
                    subtitle: "Paste one blog URL and run the full pipeline automatically — script, article check, clip prompts, voiceover, and Veo videos.",
                    systemImage: "1.circle.fill",
                    tint: .orange
                ) {
                    store.newProjectCreationMode = .automaticFull
                    store.showNewProjectSheet = true
                }
                .frame(maxWidth: 420)
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func creationCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("Start")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
