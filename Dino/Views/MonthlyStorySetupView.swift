import SwiftUI

struct MonthlyStorySetupView: View {
    let service: any MonthlyStoryClientService
    let onSaved: (MonthlyStorySettings) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: MonthlyStorySettings
    @State private var remoteVisible = true
    @State private var remoteAudioAvailable = false
    @State private var isSaving = false
    @State private var showsError = false

    init(service: any MonthlyStoryClientService,
         initialSettings: MonthlyStorySettings,
         onSaved: @escaping (MonthlyStorySettings) -> Void) {
        self.service = service
        self.onSaved = onSaved
        _draft = State(initialValue: initialSettings)
    }

    var body: some View {
        NavigationStack {
            Group {
                if remoteVisible {
                    Form {
                        Section {
                            Toggle("monthly story", isOn: $draft.enabled)
                                .accessibilityHint("Controls only the private monthly story feature.")
                        } footer: {
                            Text("a private reflection on the month, made only from the parts of dino you choose.")
                        }

                        Section("parts you choose") {
                            Toggle("use journal themes", isOn: $draft.useJournalThemes)
                                .disabled(!draft.enabled)
                                .accessibilityHint("Does not change journal theme learning elsewhere in dino.")
                            Toggle("use health patterns", isOn: $draft.useHealthPatterns)
                                .disabled(!draft.enabled)
                                .accessibilityHint("Does not request or change health permissions.")
                            Toggle("create spoken version", isOn: $draft.audioEnabled)
                                .disabled(!draft.enabled || !remoteAudioAvailable)
                                .accessibilityHint("Allows you to explicitly create a private spoken version after your written story is ready.")
                            Text(remoteAudioAvailable ?
                                 "audio is created only when you ask for it" : "spoken stories are unavailable right now")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView("monthly story is unavailable",
                                           systemImage: "book.closed",
                                           description: Text("this private preview is not available right now."))
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationTitle("your monthly story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { Task { await save() } }
                        .disabled(!remoteVisible || isSaving)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onChange(of: draft.enabled) { _, enabled in
                if !enabled {
                    draft.useJournalThemes = false
                    draft.useHealthPatterns = false
                    draft.audioEnabled = false
                }
            }
            .task { await refreshAvailability() }
            .alert("couldn't save", isPresented: $showsError) {
                Button("ok", role: .cancel) {}
            } message: {
                Text("your choices are unchanged. please try again later.")
            }
        }
    }

    private func refreshAvailability() async {
        do {
            let availability = try await service.loadFeatureAvailability()
            remoteVisible = availability.visible
            remoteAudioAvailable = availability.audioGenerationEnabled
            if !remoteAudioAvailable { draft.audioEnabled = false }
        } catch {
            remoteVisible = false
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await service.updateSettings(draft.sanitized(audioAvailable: remoteAudioAvailable))
            onSaved(saved)
            dismiss()
        } catch {
            showsError = true
        }
    }
}
