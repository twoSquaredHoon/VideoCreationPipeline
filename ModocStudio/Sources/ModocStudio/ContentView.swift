import SwiftUI

extension View {
    /// Keep view alive in a ZStack without forcing window size when another section is visible.
    func keepAliveSection(active: Bool) -> some View {
        frame(maxWidth: active ? .infinity : 0, maxHeight: active ? .infinity : 0)
            .clipped()
            .opacity(active ? 1 : 0)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore

    private var sectionTitle: String {
        switch store.appSection {
        case .home: return "Modoc Studio"
        case .browse: return "Browse Projects"
        case .pipeline: return "Run Pipeline"
        case .stats:
            switch store.statsSubsection {
            case .hub: return "Stats"
            case .projects: return "Completed Articles"
            case .time: return "Pipeline Time"
            }
        case .videoReview: return "Video Review"
        case .prompts: return "Prompts"
        }
    }

    var body: some View {
        ZStack {
            HomeView()
                .keepAliveSection(active: store.appSection == .home)

            BrowseProjectsView()
                .keepAliveSection(active: store.appSection == .browse)

            PipelineWorkspaceView()
                .keepAliveSection(active: store.appSection == .pipeline)

            GlobalStatsView()
                .keepAliveSection(active: store.appSection == .stats)

            VideoReviewView()
                .keepAliveSection(active: store.appSection == .videoReview)

            PromptsEditorView()
                .keepAliveSection(active: store.appSection == .prompts)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .navigationTitle(sectionTitle)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if store.appSection == .stats, store.statsSubsection != .hub {
                    Button {
                        store.statsGoToHub()
                    } label: {
                        Label("Stats", systemImage: "chevron.left")
                    }
                    .help("Back to Stats")
                }

                if store.appSection != .home {
                    Button {
                        store.goHome()
                    } label: {
                        Label("Home", systemImage: "house.fill")
                    }
                    .help("Back to home")
                }
            }

            if store.appSection == .browse || store.appSection == .videoReview {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        if store.isRefreshingProjects {
                            ProgressView().controlSize(.small)
                        }
                        Button {
                            store.scheduleRefreshProjects(autoSelect: false, delayMs: 0)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh projects")
                    }
                }
            }

            if store.appSection == .stats {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.requestStatsRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh stats")
                }
            }

            if store.pipeline.isRunning {
                ToolbarItem(placement: .status) {
                    PipelineRunningStatusChip()
                }
            }
        }
    }
}

private struct PipelineRunningStatusChip: View {
    @EnvironmentObject private var store: ProjectStore

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(statusLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if store.activePipelineProjectID != nil {
                Button("View project") {
                    store.openActivePipelineProject()
                }
                .buttonStyle(.borderless)
                .font(.callout)
            }
        }
        .padding(.horizontal, 4)
    }

    private var statusLabel: String {
        if let step = store.pipeline.runningStep {
            return step.title
        }
        return "Pipeline running"
    }
}
