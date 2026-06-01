//
//  ProfileView.swift
//  Dino
//

import SwiftUI
import StoreKit

// MARK: - Local Tokens (scrapbook palette)

// MARK: - Reauthentication Sheet

private struct ReauthSheet: View {
    @Binding var password: String
    @Binding var isWorking: Bool
    let providerID: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("confirm it's you")
                    .font(.title3.bold())
                Text("to permanently delete your account, please verify your identity.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                if providerID == "password" {
                    SecureField("password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                } else if providerID == "google.com" {
                    Text("you'll be asked to sign in with google again.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if providerID == "apple.com" {
                    Text("you'll be asked to sign in with apple again.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button(action: onConfirm) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text("continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking || (providerID == "password" && password.isEmpty) || (providerID == "apple.com" && isWorking))
                .padding(.horizontal)

                Button("cancel", action: onCancel)
                    .disabled(isWorking)

                Spacer()
            }
            .padding(.top, 32)
        }
        .presentationDetents([.medium])
    }
}

private enum SB {
    static let paperCream   = Color(hex: "#FBF5E4")
    static let paperWhite   = Color(hex: "#FFFDF5")
    static let sage         = Color(hex: "#6D8B74")
    static let nearBlack    = Color(hex: "#2D3A2B")
    static let peach        = Color(hex: "#F6C99F")
    static let sky          = Color(hex: "#BBD8E0")
    static let lavender     = Color(hex: "#C3B3E0")
    static let rose         = Color(hex: "#E8A09A")
    static let rust         = Color(hex: "#B88A60")
    static let xpTrack      = Color(hex: "#E8DFCF")
}

// MARK: - Sheet enum + ComingSoon model

private struct ComingSoonContent: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String

    init(_ title: String, _ subtitle: String) {
        self.id = title
        self.title = title
        self.subtitle = subtitle
    }
}

private enum ProfileSheet: Identifiable {
    case themeSettings
    case privacyPolicy
    case assessment
    case resources
    case gratitudeJar
    case growth
    case profileDetails
    case gentleReminders
    case windDown
    case textSize
    case feedback
    case ambientSounds
    case stub(ComingSoonContent)

    var id: String {
        switch self {
        case .themeSettings: return "themeSettings"
        case .privacyPolicy: return "privacyPolicy"
        case .assessment:    return "assessment"
        case .resources:     return "resources"
        case .gratitudeJar:  return "gratitudeJar"
        case .growth:        return "growth"
        case .profileDetails: return "profileDetails"
        case .gentleReminders: return "gentleReminders"
        case .windDown:      return "windDown"
        case .textSize:      return "textSize"
        case .feedback: return "feedback"
        case .ambientSounds: return "ambientSounds"
        case .stub(let c):   return "stub-\(c.id)"
        }
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var dataManager: SharedDataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var activeSheet: ProfileSheet?
    @State private var showAmbientSounds: Bool = false
    @State private var showForestLetter: Bool = false
    @State private var showRateAlert: Bool = false
    @AppStorage("dino.showStreak") private var showStreak: Bool = true
    @AppStorage("dino.streakHintSeen") private var streakHintSeen: Bool = false
    @State private var streakBurst: Bool = false
    @State private var resumeBurst: Bool = false
    @State private var navigateToStreak: Bool = false
    @State private var showSignOutConfirm = false
    @State private var showClearDataConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var savedProfilePhoto: UIImage? = nil
    @State private var accountDeletionErrorMessage: String?
    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var reauthIsWorking = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: Derived values

    private var firstName: String {
        // Read from SharedDataManager (per-user, namespaced) rather than the
        // bare UserDefaults "userName" key, which used to bleed across accounts.
        let trimmed = dataManager.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "friend" }
        return trimmed.split(separator: " ").first.map(String.init) ?? "friend"
    }

    private var joinDateLabel: String {
        let date = (UserDefaults.standard.object(forKey: "userJoinDate") as? Date) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    /// Union-of-practices streak.
    private var unionStreak: Int {
        let cal = Calendar.current
        var set = Set<Date>()
        dataManager.journalEntries.forEach { set.insert(cal.startOfDay(for: $0.date)) }
        dataManager.moodEntries.forEach { set.insert(cal.startOfDay(for: $0.date)) }
        dataManager.gratitudeNotes.forEach { set.insert(cal.startOfDay(for: $0.createdAt)) }
        dataManager.breathingSessions.forEach { set.insert(cal.startOfDay(for: $0.date)) }

        guard !set.isEmpty else { return 0 }

        let today = cal.startOfDay(for: Date())
        var cursor = today
        if !set.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  set.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while set.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private var xpLevel: Int { dataManager.growthStats.level }
    private var xpInLevel: Int { dataManager.growthStats.xpInCurrentLevel }
    private var xpToNext: Int { dataManager.growthStats.xpToNextLevel }
    private var xpProgress: Double { dataManager.growthStats.xpProgress }

    private var moodQuote: String {
        switch themeManager.currentTheme {
        case .sunny:        return "little suns bloom\neven on quiet days"
        case .rainy:        return "the garden drinks\nwhat the sky forgets"
        case .cloudy:       return "soft skies hold you\nwithout asking why"
        case .night:        return "rest is a kind\nof tending too"
        case .forest:       return "grow slow.\nthe woods aren't in a rush"
        case .lavenderCalm: return "you smell like\nsomething gentle"
        case .snow:         return "even stillness\nkeeps you alive"
        case .storm:        return "the tree still stands\nafter the wind"
        case .defaultDino:  return "little you\nis doing enough"
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerRow
                        .padding(.top, 14)

                    polaroidRow

                    statsStickersRow
                        .padding(.top, 4)

                    xpPill
                        .padding(.top, 2)

                    tornQuoteSlip
                        .padding(.top, 6)

                    sectionPractice
                    sectionJourney
                    sectionAppearance
                    sectionAccount
                    sectionWellness
                    sectionAbout

                    footer
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
            }
            .background(ScrapbookBackground().ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear {
            savedProfilePhoto = PhotoStore.load()
            if UserDefaults.standard.object(forKey: "userJoinDate") == nil {
                UserDefaults.standard.set(Date(), forKey: "userJoinDate")
            }
            AnalyticsManager.shared.trackProfileOpened()
            AnalyticsManager.shared.trackScreen("profile")
        }
        .sheet(item: $activeSheet, onDismiss: {
            savedProfilePhoto = PhotoStore.load()
        }) { sheet in
            switch sheet {
            case .themeSettings:
                // ThemeSettingsView declares `@EnvironmentObject var themeManager: ThemeManager`.
                // Sheet content does NOT inherit the presenting view's environment, so we must
                // inject ThemeManager.shared here or SwiftUI will fatalError at runtime with
                // "No ObservableObject of type ThemeManager found".
                ThemeSettingsView()
                    .environmentObject(ThemeManager.shared)
                    .environmentObject(dataManager)
            case .privacyPolicy: PrivacyPolicyView()
            case .assessment:    AssessmentView().environmentObject(dataManager)
            case .resources:     ResourcesView()
            case .gratitudeJar:  GratitudeJarView().environmentObject(dataManager)
            case .growth:        NavigationStack { GrowthView().environmentObject(dataManager) }
            case .profileDetails: ProfileDetailsView().environmentObject(dataManager)
            case .gentleReminders:
                SettingsView().environmentObject(dataManager)
            case .windDown:      WindDownView()
            case .textSize:      TextSizeView()
            case .feedback: FeedbackView()
            case .ambientSounds: EmptyView() // presented via fullScreenCover instead
            case .stub(let content): ComingSoonView(content: content)
            }
        }
        .fullScreenCover(isPresented: $showForestLetter) {
            ForestLetterView(
                onEnter: {
                    // Dismiss the letter, then present the waterfall once SwiftUI
                    // finishes the dismiss animation. The audio is already fading
                    // in from inside ForestLetterView.enterForest().
                    showForestLetter = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showAmbientSounds = true
                    }
                },
                onDismiss: {
                    showForestLetter = false
                }
            )
        }
        .fullScreenCover(isPresented: $showAmbientSounds) {
            AmbientSoundsView()
        }
        .alert("enjoying dino?", isPresented: $showRateAlert) {
            Button("rate now") { requestReview() }
            Button("maybe later", role: .cancel) {}
        } message: {
            Text("your rating helps us reach more people 🌿")
        }
        .confirmationDialog(
            "sign out?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("sign out", role: .destructive) {
                AuthManager.shared.signOut()
                dataManager.clearForSignOut()
                UserDefaults.standard.set(false, forKey: "hasPassedAuth")
                dismiss()
            }
            Button("cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "clear all data?",
            isPresented: $showClearDataConfirm,
            titleVisibility: .visible
        ) {
            Button("clear everything", role: .destructive) {
                dataManager.clearAllData()
                dismiss()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will delete all your moods, journals and gratitude. are you sure?")
        }
        .confirmationDialog(
            "delete your account?",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("delete forever", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this will permanently delete your account, all your data from the cloud, and sign you out. this cannot be undone. are you sure?")
        }
        .alert("couldn't delete account", isPresented: Binding(
            get: { accountDeletionErrorMessage != nil },
            set: { if !$0 { accountDeletionErrorMessage = nil } }
        )) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(accountDeletionErrorMessage ?? "please try again.")
        }
        .sheet(isPresented: $showReauthSheet) {
            ReauthSheet(
                password: $reauthPassword,
                isWorking: $reauthIsWorking,
                providerID: AuthManager.shared.currentProviderID ?? "",
                onConfirm: {
                    Task { await performReauthAndDelete() }
                },
                onCancel: {
                    showReauthSheet = false
                    reauthPassword = ""
                }
            )
        }
    }

    private func deleteAccount() async {
        // Correct order:
        // 1. Delete Auth account first (with reauthentication if required)
        // 2. Then Firestore data
        // 3. Then local data
        // On any failure, do NOT delete data and do NOT sign out.
        do {
            try await AuthManager.shared.deleteAuthAccount()
        } catch AccountDeletionError.requiresReauthentication {
            // Need fresh login — present reauth sheet, then retry.
            showReauthSheet = true
            return
        } catch {
            #if DEBUG
            print("[Profile] account deletion error")
            #endif
            accountDeletionErrorMessage = error.localizedDescription
            return
        }

        await finalizeAccountDeletion()
    }

    private func performReauthAndDelete() async {
        reauthIsWorking = true
        defer { reauthIsWorking = false }
        let providerID = AuthManager.shared.currentProviderID ?? ""
        do {
            if providerID == "password" {
                try await AuthManager.shared.reauthenticateEmailUser(password: reauthPassword)
            } else if providerID == "google.com" {
                try await AuthManager.shared.reauthenticateGoogleUser()
            } else if providerID == "apple.com" {
                try await AuthManager.shared.reauthenticateAppleUser()
            } else {
                throw AccountDeletionError.noProvider
            }
        } catch {
            accountDeletionErrorMessage = error.localizedDescription
            return
        }

        showReauthSheet = false
        reauthPassword = ""

        // Retry the auth deletion now that we're freshly authenticated.
        do {
            try await AuthManager.shared.deleteAuthAccount()
        } catch {
            accountDeletionErrorMessage = error.localizedDescription
            return
        }

        await finalizeAccountDeletion()
    }

    private func finalizeAccountDeletion() async {
        // Auth account is gone — now delete Firestore data.
        // Local clear ONLY runs on Firestore success.
        do {
            try await FirestoreSyncService.shared.deleteAllUserData()
        } catch {
            #if DEBUG
            print("[Profile] firestore cleanup after auth delete failed")
            #endif
            accountDeletionErrorMessage = error.localizedDescription
            return
        }

        AuthManager.shared.clearLocalAuthSession()
        dataManager.clearForSignOut()
        UserDefaults.standard.set(false, forKey: "hasPassedAuth")
        dismiss()
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: -2) {
                Text("my little")
                    .font(DinoTheme.dinoFont(size: 22))
                    .foregroundColor(SB.sage)
                Text("scrapbook")
                    .font(DinoTheme.dinoFont(size: 34))
                    .foregroundColor(SB.nearBlack)
            }
            .rotationEffect(.degrees(-1))

            Spacer()

            ZStack {
                Circle()
                    .strokeBorder(
                        SB.rust,
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    )
                    .frame(width: 58, height: 58)
                Text("page 1")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(SB.rust)
            }
            .rotationEffect(.degrees(6))
            .padding(.top, 6)
        }
    }

    // MARK: - Polaroid Row

    private var polaroidRow: some View {
        HStack(alignment: .center, spacing: 16) {
            DinoPolaroid(profilePhoto: savedProfilePhoto)
            VStack(alignment: .leading, spacing: 4) {
                Text("hello,")
                    .font(DinoTheme.dinoFont(size: 16))
                    .foregroundColor(SB.sage)
                Text(firstName)
                    .font(DinoTheme.dinoFont(size: 28))
                    .foregroundColor(SB.nearBlack)
                    .rotationEffect(.degrees(-0.8))
                Text("it's good to see you")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(SB.sage.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Stats stickers row

    private var statsStickersRow: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                ZStack {
                    StickerCircle(
                        number: "\(unionStreak)",
                        label: "day streak",
                        innerRing: SB.peach,
                        tilt: 3,
                        paused: !showStreak,
                        resumeBurst: resumeBurst
                    )
                    if streakBurst {
                        Text("\u{1F525}")
                            .font(.system(size: 32))
                            .scaleEffect(1.4)
                            .opacity(0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: streakBurst)
                    }
                }
                .contentShape(Rectangle())
                .navigationDestination(isPresented: $navigateToStreak) {
                    StreakCalendarView().environmentObject(dataManager)
                }
                .onTapGesture {
                    HapticManager.shared.light()
                    navigateToStreak = true
                    if !streakHintSeen {
                        withAnimation(.easeOut(duration: 0.3)) {
                            streakHintSeen = true
                        }
                    }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    toggleStreakDisplay()
                }
                if !showStreak {
                    Text("paused")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(Color(hex: "#A8A29A"))
                        .transition(.opacity)
                } else if !streakHintSeen {
                    Text("hold to pause 🌿")
                        .font(.system(size: 10))
                        .italic()
                        .foregroundColor(Color(hex: "#A8A29A"))
                        .transition(.opacity)
                }
            }

            Button {
                activeSheet = .gratitudeJar
            } label: {
                StickerCircle(
                    number: "\(dataManager.gratitudeNotes.count)",
                    label: "slips saved",
                    innerRing: SB.sky,
                    tilt: -4
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    // MARK: - XP pill

    private var xpPill: some View {
        Button {
            activeSheet = .growth
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(SB.sage)

                Text("level \(xpLevel)")
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(SB.nearBlack)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SB.xpTrack)
                        .frame(width: 100, height: 6)
                    Capsule()
                        .fill(SB.lavender)
                        .frame(width: max(6, 100 * CGFloat(xpProgress)), height: 6)
                }

                Text("\(xpInLevel) / \(xpToNext) xp")
                    .font(DinoTheme.numericFont(size: 12))
                    .foregroundColor(SB.sage)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(SB.paperWhite)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        SB.sage,
                        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                    )
            )
            .rotationEffect(.degrees(1.2))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Torn Quote Slip

    private var tornQuoteSlip: some View {
        ZStack(alignment: .top) {
            TornPaper()
                .fill(SB.paperWhite)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 1, y: 3)

            // Washi tape at top
            RoundedRectangle(cornerRadius: 2)
                .fill(SB.rose.opacity(0.7))
                .frame(width: 80, height: 14)
                .rotationEffect(.degrees(-3))
                .offset(y: -6)

            VStack(spacing: 10) {
                Text(moodQuote)
                    .italic()
                    .multilineTextAlignment(.center)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(SB.nearBlack)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— dino")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(SB.sage.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .rotationEffect(.degrees(-1.5))
    }

    // MARK: - Streak toggle

    private func toggleStreakDisplay() {
        HapticManager.shared.medium()
        if showStreak {
            withAnimation(.easeOut(duration: 0.4)) {
                showStreak = false
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showStreak = true
            }
            resumeBurst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    resumeBurst = false
                }
            }
            streakBurst = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                streakBurst = false
            }
        }
        if !streakHintSeen {
            withAnimation(.easeOut(duration: 0.3)) {
                streakHintSeen = true
            }
        }
    }

    // MARK: - Sections

    private var sectionJourney: some View {
        PaperSection(
            label: "your journey \u{1F4C8}",
            tapeColor: SB.peach,
            tilt: 0.5
        ) {
            NavigationLink {
                WellnessProgressView()
                    .environmentObject(dataManager)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(SB.sage)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(SB.sage.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("see your wellness trend")
                            .font(DinoTheme.dinoFont(size: 16))
                            .foregroundColor(SB.nearBlack)
                        Text("last 8 weeks of mood + assessments")
                            .font(DinoTheme.dinoFont(size: 12))
                            .foregroundColor(SB.sage)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SB.sage)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
    }

    private var sectionPractice: some View {
        PaperSection(
            label: "practice",
            tapeColor: SB.peach,
            tilt: -0.8
        ) {
            SBRow(
                icon: "bell.fill",
                iconColor: SB.sage,
                title: "gentle reminders",
                subtitle: "nudges from your dino"
            ) {
                activeSheet = .gentleReminders
            }
            AmbientSoundsRow {
                showAmbientSounds = true
            }
            SBRow(
                icon: "moon.stars.fill",
                iconColor: SB.lavender,
                title: "wind down",
                subtitle: "a quiet end to the day"
            ) {
                activeSheet = .windDown
            }
        }
    }

    private var sectionAppearance: some View {
        PaperSection(
            label: "appearance",
            tapeColor: SB.sage.opacity(0.35),
            tilt: 1.0
        ) {
            SBRow(
                icon: "paintpalette.fill",
                iconColor: SB.rose,
                title: "theme & weather",
                subtitle: "current: \(themeManager.currentTheme.displayName)"
            ) {
                activeSheet = .themeSettings
            }
            SBRow(
                icon: "textformat.size",
                iconColor: SB.sky,
                title: "text size",
                subtitle: "make reading gentle"
            ) {
                activeSheet = .textSize
            }

            // Quick palette swatches
            VStack(alignment: .leading, spacing: 8) {
                Text("quick palette")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(SB.sage)

                HStack(spacing: 12) {
                    ForEach(Array([SB.peach, SB.sky, SB.lavender, SB.rose].enumerated()),
                            id: \.offset) { _, swatch in
                        Button {
                            activeSheet = .themeSettings
                        } label: {
                            Circle()
                                .fill(swatch)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().strokeBorder(
                                        SB.sage.opacity(0.6),
                                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, 4)
        }
    }

    private var sectionAccount: some View {
        PaperSection(
            label: "account",
            tapeColor: SB.sky,
            tilt: -1.0
        ) {
            SBRow(
                icon: "person.fill",
                iconColor: SB.sage,
                title: "profile details",
                subtitle: "name, avatar"
            ) {
                activeSheet = .profileDetails
            }
            SBRow(
                icon: "lock.shield.fill",
                iconColor: SB.lavender,
                title: "privacy & data",
                subtitle: "your data, your garden"
            ) {
                activeSheet = .privacyPolicy
            }
            SBRow(
                icon: "trash",
                iconColor: SB.rose,
                title: "clear all data",
                subtitle: "start with a fresh page"
            ) {
                showClearDataConfirm = true
            }
            SBRow(
                icon: "person.slash",
                iconColor: Color.red,
                title: "delete account",
                subtitle: "permanently remove everything"
            ) {
                showDeleteAccountConfirm = true
            }
        }
    }

    private var sectionWellness: some View {
        PaperSection(
            label: "wellness",
            tapeColor: SB.lavender,
            tilt: 0.8
        ) {
            SBRow(
                icon: "brain.head.profile",
                iconColor: SB.lavender,
                title: "weekly check-in",
                subtitle: "5 gentle questions"
            ) {
                activeSheet = .assessment
            }
            SBRow(
                icon: "heart.text.square.fill",
                iconColor: SB.sage,
                title: "resources",
                subtitle: "grounding, crisis, kindness"
            ) {
                activeSheet = .resources
            }
            SBRow(
                icon: "exclamationmark.bubble.fill",
                iconColor: SB.rose,
                title: "need help now?",
                subtitle: "someone will answer, always"
            ) {
                activeSheet = .resources
            }
        }
    }

    private var sectionAbout: some View {
        PaperSection(
            label: "about",
            tapeColor: SB.rose,
            tilt: -0.6
        ) {
            SBRow(
                icon: "questionmark.circle.fill",
                iconColor: SB.sky,
                title: "help & feedback",
                subtitle: "tell us what's growing"
            ) {
                activeSheet = .feedback
            }
            SBRow(
                icon: "heart.fill",
                iconColor: SB.rose,
                title: "rate dino",
                subtitle: "if it's helping your days"
            ) {
                showRateAlert = true
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(SB.sage.opacity(0.5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("version")
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(SB.nearBlack)
                    Text("current build")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(SB.sage)
                }

                Spacer(minLength: 0)

                Text(appVersion)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(SB.sage.opacity(0.8))
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                showSignOutConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                    Text("sign out")
                        .font(DinoTheme.dinoFont(size: 15))
                }
                .foregroundColor(SB.rose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Text("xo, dino")
                .italic()
                .font(DinoTheme.dinoFont(size: 16))
                .foregroundColor(SB.sage.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)

            Text("dino · v1.2.0")
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(SB.sage.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)

            Text("member since \(joinDateLabel)")
                .font(DinoTheme.dinoFont(size: 11))
                .foregroundColor(SB.sage.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Scrapbook Background

private struct ScrapbookBackground: View {
    var body: some View {
        ZStack {
            SB.paperCream
            Canvas { ctx, size in
                let lineColor = SB.sage.opacity(0.08)
                var y: CGFloat = 0
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(lineColor), lineWidth: 0.8)
                    y += 28
                }
            }
        }
    }
}

// MARK: - DinoPolaroid

private struct DinoPolaroid: View {
    let profilePhoto: UIImage?

    var body: some View {
        ZStack {
            // White card
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 130, height: 130)

            Group {
                if let img = profilePhoto {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 114, height: 114)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                } else {
                    Image.cached("DinoMascot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 114, height: 114)
                }
            }
            .padding(8)

            // Tape top-left
            RoundedRectangle(cornerRadius: 1)
                .fill(SB.peach.opacity(0.7))
                .frame(width: 48, height: 14)
                .rotationEffect(.degrees(-8))
                .offset(x: -40, y: -60)

            // Tape top-right
            RoundedRectangle(cornerRadius: 1)
                .fill(SB.peach.opacity(0.7))
                .frame(width: 48, height: 14)
                .rotationEffect(.degrees(8))
                .offset(x: 40, y: -60)
        }
        .rotationEffect(.degrees(-3))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 2, y: 4)
        .frame(width: 150, height: 150)
    }
}

// MARK: - Sticker Circle

private struct StickerCircle: View {
    let number: String
    let label: String
    let innerRing: Color
    let tilt: Double
    var paused: Bool = false
    var resumeBurst: Bool = false

    @State private var pulseScale: CGFloat = 1.0

    private var mutedGrey: Color { Color(hex: "#E8E4D5") }
    private var sageLeaf: Color { Color(hex: "#A8C5A0") }

    var body: some View {
        ZStack {
            if paused {
                Circle()
                    .fill(mutedGrey)
                Circle()
                    .strokeBorder(
                        sageLeaf.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(sageLeaf)
            } else {
                Circle()
                    .fill(SB.paperWhite)
                Circle()
                    .strokeBorder(
                        SB.sage,
                        style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                    )
                Circle()
                    .strokeBorder(innerRing, lineWidth: 3)
                    .padding(6)
                VStack(spacing: 0) {
                    Text(number)
                        .font(DinoTheme.numericFont(size: 22))
                        .foregroundColor(SB.nearBlack)
                    Text(label)
                        .font(DinoTheme.dinoFont(size: 11))
                        .foregroundColor(SB.sage)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 6)
            }
        }
        .frame(width: 84, height: 84)
        .scaleEffect(paused ? pulseScale : (resumeBurst ? 1.2 : 1.0))
        .rotationEffect(.degrees(tilt))
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
}

// MARK: - Torn Paper Shape

private struct TornPaper: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tearAmplitude: CGFloat = 4
        let tearStep: CGFloat = 10

        // Guard against pre-layout zero / non-finite sizes — the original
        // `while x <= rect.width` loop advances via `min(x + step, width)`,
        // which pins x to 0 when width is 0 and spins forever.
        guard rect.width.isFinite, rect.height.isFinite,
              rect.width > 0, rect.height > 0 else {
            path.addRect(rect)
            return path
        }

        path.move(to: CGPoint(x: 0, y: tearAmplitude))

        var x: CGFloat = 0
        var goingDown = true
        while x < rect.width {
            let nextX = min(x + tearStep, rect.width)
            let y: CGFloat = goingDown ? tearAmplitude * 2 : 0
            path.addLine(to: CGPoint(x: nextX, y: y))
            if nextX == x { break } // belt-and-braces: never loop on no progress
            x = nextX
            goingDown.toggle()
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Paper Section (card with washi tape, label, contents)

private struct PaperSection<Content: View>: View {
    let label: String
    let tapeColor: Color
    let tilt: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SB.paperWhite)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 1, y: 3)

            // Washi tape at top-center
            RoundedRectangle(cornerRadius: 2)
                .fill(tapeColor)
                .frame(width: 62, height: 16)
                .rotationEffect(.degrees(tilt >= 0 ? 6 : -6))
                .offset(y: -8)

            VStack(alignment: .leading, spacing: 10) {
                Text(label.uppercased())
                    .font(DinoTheme.dinoFont(size: 13))
                    .tracking(2)
                    .foregroundColor(SB.sage)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    content()
                }
            }
            .padding(16)
        }
        .rotationEffect(.degrees(tilt))
        .padding(.top, 6)
    }
}

// MARK: - Ambient Sounds Row

private struct AmbientSoundsRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(SB.peach)
                        .frame(width: 36, height: 36)
                    Image(systemName: "music.note")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ambient sounds")
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(SB.nearBlack)
                    Text("rain, forest, soft piano")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(SB.sage)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SB.sage.opacity(0.55))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scrapbook Row

private struct SBRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DinoTheme.dinoFont(size: 16))
                        .foregroundColor(SB.nearBlack)
                    Text(subtitle)
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(SB.sage)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SB.sage.opacity(0.5))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coming Soon View

private struct ComingSoonView: View {
    let content: ComingSoonContent

    var body: some View {
        ZStack {
            SB.paperCream.ignoresSafeArea()
            VStack(spacing: 18) {
                Image("DinoSleeping")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)

                Text(content.title)
                    .font(DinoTheme.dinoFont(size: 24))
                    .foregroundColor(SB.nearBlack)
                    .multilineTextAlignment(.center)

                Text(content.subtitle)
                    .font(DinoTheme.dinoFont(size: 15))
                    .foregroundColor(SB.sage)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Text("coming soon")
                    .font(DinoTheme.dinoFont(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(SB.rose))
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}
