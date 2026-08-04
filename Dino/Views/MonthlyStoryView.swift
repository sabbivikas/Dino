import SwiftUI

struct MonthlyStoryView: View {
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: MonthlyStoryReaderModel
    @State private var showsDeleteConfirmation = false

    init(story: MonthlyStoryDocument,
         service: any MonthlyStoryClientService,
         onDeleted: @escaping () -> Void) {
        self.onDeleted = onDeleted
        _model = StateObject(wrappedValue: MonthlyStoryReaderModel(story: story, service: service))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .ready(let story): storyBody(story)
                case .deleted: deletedBody
                case .loading: ProgressView("opening your story")
                    .accessibilityLabel("opening your monthly story")
                case .unavailable: unavailableBody
                default: unavailableBody
                }
            }
            .background(DinoTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                if case .ready = model.state {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) { showsDeleteConfirmation = true } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("delete this monthly story")
                    }
                }
            }
            .task { await model.refreshRemoteAvailability() }
            .confirmationDialog("delete this story?",
                                isPresented: $showsDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("delete story", role: .destructive) {
                    Task {
                        await model.deleteStory()
                        if model.state == .deleted { onDeleted() }
                    }
                }
                Button("keep story", role: .cancel) {}
            } message: {
                Text("the written story and any future audio for this month will be removed. it will not be regenerated for this month in this version of dino.")
            }
            .alert("couldn't delete story", isPresented: $model.showsDeletionError) {
                Button("ok", role: .cancel) {}
            } message: {
                Text("your story is still here. please try again later.")
            }
        }
    }

    private func storyBody(_ story: MonthlyStoryDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.displayMonth.lowercased())
                        .font(DinoTheme.captionFont())
                        .foregroundStyle(DinoTheme.sageGreen)
                        .textCase(.uppercase)
                    Text("your month, in a few quiet pages")
                        .font(DinoTheme.titleFont())
                        .foregroundStyle(DinoTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your \(story.displayMonth) monthly story")

                ForEach(Array(story.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(paragraph)
                        .font(DinoTheme.serifFont(size: 19))
                        .foregroundStyle(DinoTheme.textPrimary)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Paragraph \(index + 1). \(paragraph)")
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 64)
        }
        .accessibilityElement(children: .contain)
    }

    private var deletedBody: some View {
        ContentUnavailableView("story removed",
                               systemImage: "checkmark.circle",
                               description: Text("this month's story will not be recreated."))
            .accessibilityLabel("Monthly story removed. It will not be recreated.")
    }

    private var unavailableBody: some View {
        ContentUnavailableView("story unavailable",
                               systemImage: "book.closed",
                               description: Text("this private reflection cannot be opened right now."))
            .accessibilityLabel("Monthly story unavailable")
    }
}
