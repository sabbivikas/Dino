import SwiftUI

struct MonthlyStoryCard: View {
    let state: MonthlyStoryViewState
    let onOpen: () -> Void
    let onSettings: () -> Void

    private var presentation: (title: String, body: String, icon: String) {
        switch state {
        case .idle, .loading:
            return ("your monthly story", "gathering this private space…", "book.closed")
        case .settingsDisabled:
            return ("your monthly story", "a private reflection on the month, made only from the parts of dino you choose.", "book.closed")
        case .noStory:
            return ("your monthly story", "there is not enough of the month yet. your story will appear here when it is ready.", "calendar")
        case .preparing:
            return ("your monthly story", "your private reflection is being prepared.", "hourglass")
        case .ready(let story):
            return ("your \(story.displayMonth.lowercased()) story is ready", "a quiet keepsake from the month.", "book.pages")
        case .unavailable:
            return ("your monthly story", "this private reflection is unavailable right now.", "book.closed")
        case .failed:
            return ("your monthly story", "this story could not be prepared. nothing has been shared.", "leaf")
        case .deleted:
            return ("story removed", "this month's story has been deleted and will not be recreated.", "checkmark.circle")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: presentation.icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(DinoTheme.sageGreen)
                    .frame(width: 44, height: 44)
                    .background(DinoTheme.sageGreen.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.title)
                        .font(DinoTheme.headlineFont())
                        .foregroundStyle(DinoTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.body)
                        .font(DinoTheme.subheadlineFont())
                        .foregroundStyle(DinoTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("monthly story settings")
            }

            Button(action: onOpen) {
                HStack {
                    Text(state.openButtonTitle)
                        .font(DinoTheme.bodyFont())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(DinoTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 14)
                .background(DinoTheme.sageGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.openButtonAccessibilityLabel)
        }
        .padding(18)
        .background(DinoTheme.cardBackground, in: RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: DinoTheme.largeCornerRadius)
                .stroke(DinoTheme.cardBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private extension MonthlyStoryViewState {
    var openButtonTitle: String {
        switch self {
        case .ready: "read story"
        case .settingsDisabled: "choose what to include"
        case .noStory: "prepare my story"
        case .preparing: "preparing…"
        default: "view details"
        }
    }

    var openButtonAccessibilityLabel: String {
        switch self {
        case .ready(let story): "read your \(story.displayMonth) story"
        case .settingsDisabled: "open monthly story choices"
        default: "open monthly story details"
        }
    }
}

struct MonthlyStoryCardHost: View {
    @Environment(\.monthlyStoryInternalGate) private var localGate
    @Environment(\.monthlyStoryClientService) private var service
    @State private var snapshot = MonthlyStoryExperienceSnapshot.hidden
    @State private var route: Route?
    @State private var isPreparing = false
    #if MONTHLY_STORY_INTERNAL_BUILD
    @State private var internalDiagnostic = "local gate disabled"
    #endif
    let dataManager: SharedDataManager?
    let journalThemeLearningEnabled: Bool

    init(dataManager: SharedDataManager? = nil, journalThemeLearningEnabled: Bool = false) {
        self.dataManager = dataManager
        self.journalThemeLearningEnabled = journalThemeLearningEnabled
    }

    private enum Route: Identifiable {
        case setup
        case reader(MonthlyStoryDocument)

        var id: String {
            switch self {
            case .setup: "setup"
            case .reader(let story): "reader-\(story.id)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if snapshot.isVisible {
                MonthlyStoryCard(state: snapshot.state,
                                 onOpen: openPrimaryDestination,
                                 onSettings: { route = .setup })
                    .transition(.opacity)
            }
            #if MONTHLY_STORY_INTERNAL_BUILD
            Text("monthly story internal: \(internalDiagnostic)")
                .font(.caption2)
                .foregroundStyle(DinoTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("monthly story internal status: \(internalDiagnostic)")
            #endif
        }
        .task { await refresh() }
        .sheet(item: $route, onDismiss: { Task { await refresh() } }) { route in
            switch route {
            case .setup:
                MonthlyStorySetupView(service: service, initialSettings: snapshot.settings) { settings in
                    snapshot = MonthlyStoryExperienceSnapshot(isVisible: true,
                                                              settings: settings,
                                                              state: settings.enabled ? .noStory : .settingsDisabled)
                }
            case .reader(let story):
                MonthlyStoryView(story: story, service: service) {
                    snapshot = MonthlyStoryExperienceSnapshot(isVisible: true,
                                                              settings: snapshot.settings,
                                                              state: .deleted)
                }
            }
        }
    }

    private func openPrimaryDestination() {
        if case .ready(let story) = snapshot.state {
            route = .reader(story)
        } else if case .noStory = snapshot.state {
            Task { await prepareStory() }
        } else {
            route = .setup
        }
    }

    private func refresh() async {
        let refreshed = await resolveMonthlyStoryExperience(localGate: localGate, service: service)
        #if MONTHLY_STORY_INTERNAL_BUILD
        internalDiagnostic = diagnosticStatus(for: refreshed)
        #endif
        if !refreshed.isVisible, case .ready = snapshot.state {
            return
        }
        snapshot = refreshed
    }

    #if MONTHLY_STORY_INTERNAL_BUILD
    private func diagnosticStatus(for refreshed: MonthlyStoryExperienceSnapshot) -> String {
        guard localGate.isEnabled else { return "local gate disabled" }
        guard refreshed.isVisible else { return "visibility disabled" }
        switch refreshed.state {
        case .unavailable(.network): return "network failure"
        case .failed: return "callable unavailable"
        default: return "availability allowed"
        }
    }
    #endif

    private func prepareStory() async {
        guard !isPreparing, let dataManager, snapshot.settings.enabled else { return }
        isPreparing = true
        snapshot = MonthlyStoryExperienceSnapshot(isVisible: true, settings: snapshot.settings, state: .preparing)
        defer { isPreparing = false }
        do {
            let availability = try await service.loadFeatureAvailability()
            guard availability.visible, availability.signalUploadEnabled,
                  availability.textGenerationEnabled else { throw MonthlyStoryClientError.featureDisabled }
            let coordinator = MonthlyStorySignalCoordinator(dataManager: dataManager,
                journalThemeLearningEnabled: journalThemeLearningEnabled)
            let signal = try await coordinator.buildSignal(settings: snapshot.settings)
            let story = try await service.prepareDeterministicStory(signal: signal)
            snapshot = MonthlyStoryExperienceSnapshot(isVisible: true, settings: snapshot.settings,
                                                      state: .ready(story))
        } catch MonthlyStorySignalCoordinatorError.insufficientEvidence {
            snapshot = MonthlyStoryExperienceSnapshot(isVisible: true, settings: snapshot.settings,
                                                      state: .noStory)
        } catch {
            snapshot = MonthlyStoryExperienceSnapshot(isVisible: true, settings: snapshot.settings,
                                                      state: .failed)
        }
    }
}
