import SwiftUI
import PhotosUI

// MARK: - PhotoStore (internal — ProfileView also reads this)

struct PhotoStore {
    private static let fileName = "profile_photo.jpg"
    private static let hasPhotoKey = "has_profile_photo"

    private static var fileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(fileName)
    }

    @discardableResult
    static func save(image: UIImage) -> Bool {
        guard let url = fileURL else { return false }

        // Scale to max 1024×1024 preserving aspect ratio
        let maxDim: CGFloat = 1024
        let scale = min(maxDim / max(image.size.width, image.size.height), 1.0)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = scaled.jpegData(compressionQuality: 0.8) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            UserDefaults.standard.set(true, forKey: hasPhotoKey)
            return true
        } catch {
            return false
        }
    }

    static func load() -> UIImage? {
        guard UserDefaults.standard.bool(forKey: hasPhotoKey),
              let url = fileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
        UserDefaults.standard.set(false, forKey: hasPhotoKey)
    }
}

// MARK: - ProfileDetailsView

struct ProfileDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoUIImage: UIImage?

    // Snapshots for dirty detection
    @State private var originalName: String = ""
    @State private var originalBio: String = ""
    @State private var originalPhoto: UIImage?

    @State private var showSavedToast = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, bio }

    private var hasChanges: Bool {
        name != originalName || bio != originalBio || photoUIImage !== originalPhoto
    }

    private var canSave: Bool {
        hasChanges && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#FBF5E4").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        avatarSection
                        nameCard
                        bioCard
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("profile details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") { dismiss() }
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundStyle(Color(hex: "#7BA872"))
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    savedToast
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear(perform: loadCurrent)
            .onChange(of: photoItem) { newItem in
                Task { await loadPickedImage(newItem) }
            }
            .onChange(of: bio) { newValue in
                if newValue.count > 150 {
                    bio = String(newValue.prefix(150))
                }
            }
        }
    }

    // MARK: Sections

    private var avatarSection: some View {
        VStack(spacing: 8) {
            PhotosPicker(
                selection: $photoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = photoUIImage {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            Image("DinoMascot").resizable().scaledToFit()
                        }
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: "#F5C5A3"), lineWidth: 3))
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color(hex: "#7BA872"))
                        .background(Color(hex: "#FBF5E4"), in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)

            Text("tap to change photo")
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundStyle(Color(hex: "#7BA872"))
        }
        .padding(.top, 8)
    }

    private var nameCard: some View {
        scrapbookCard(
            tapeColor: Color(hex: "#F5C5A3"),
            rotation: -1
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("your name")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundStyle(Color(hex: "#9E9E9E"))
                TextField("", text: $name, prompt: Text("what should we call you?"))
                    .font(DinoTheme.dinoFont(size: 17))
                    .foregroundStyle(Color(hex: "#2D3142"))
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .bio }
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var bioCard: some View {
        scrapbookCard(
            tapeColor: Color(hex: "#B8D4B0"),
            rotation: 1
        ) {
            VStack(alignment: .leading, spacing: 6) {
                Text("about you")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundStyle(Color(hex: "#9E9E9E"))
                TextEditor(text: $bio)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundStyle(Color(hex: "#2D3142"))
                    .focused($focusedField, equals: .bio)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .overlay(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("add a little something about yourself")
                                .font(DinoTheme.dinoFont(size: 15))
                                .foregroundStyle(Color(hex: "#BDBDBD"))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    Spacer()
                    Text("\(bio.count)/150")
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundStyle(
                            bio.count > 130
                                ? Color(hex: "#E8A09A")
                                : Color(hex: "#BDBDBD")
                        )
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("save")
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(
                        canSave ? Color(hex: "#7BA872") : Color(hex: "#BDBDBD")
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var savedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(hex: "#7BA872"))
            Text("saved")
                .font(DinoTheme.dinoFont(size: 14))
                .foregroundStyle(Color(hex: "#2D3142"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(hex: "#FFFDF5"))
                .overlay(Capsule().stroke(Color(hex: "#7BA872"), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .rotationEffect(.degrees(1))
    }

    // MARK: Scrapbook card helper

    @ViewBuilder
    private func scrapbookCard<Content: View>(
        tapeColor: Color,
        rotation: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#FFFDF5"))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#E8E0D0"), lineWidth: 1)
                )

            content()
                .padding(18)
                .padding(.top, 6)

            // Washi tape
            RoundedRectangle(cornerRadius: 2)
                .fill(tapeColor.opacity(0.8))
                .frame(width: 70, height: 18)
                .rotationEffect(.degrees(-4))
                .offset(y: -6)
        }
        .rotationEffect(.degrees(rotation))
    }

    // MARK: Actions

    private func loadCurrent() {
        name = UserDefaults.standard.string(forKey: "userName") ?? ""
        bio = UserDefaults.standard.string(forKey: "user_bio") ?? ""
        let loaded = PhotoStore.load()
        photoUIImage = loaded
        originalName = name
        originalBio = bio
        originalPhoto = loaded
    }

    @MainActor
    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                photoUIImage = img
            }
        } catch {
            // Silent failure — user can retry
        }
    }

    private func save() {
        // Persist
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(trimmedName, forKey: "userName")
        UserDefaults.standard.set(bio, forKey: "user_bio")

        if photoUIImage !== originalPhoto, let img = photoUIImage {
            _ = PhotoStore.save(image: img)
        }

        // Haptic
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        // Toast
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showSavedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.25)) {
                showSavedToast = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                dismiss()
            }
        }
    }
}

#Preview {
    ProfileDetailsView()
}
