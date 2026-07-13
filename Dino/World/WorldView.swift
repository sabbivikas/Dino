//
//  WorldView.swift
//  Dino
//
//  DINO WORLD — the living globe screen. Globe + peach halo, find my light,
//  week rewind chips, mood percentage bar, per-country list, anonymity footer.
//  All data comes from the single worldAggregate doc; if it's unavailable the
//  globe still renders (just unlit) and the lists stay gentle, never broken.
//

import SwiftUI

struct WorldView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var aggregate: WorldAggregate?
    @State private var selectedDayKey: String = ""
    @State private var findTrigger = 0
    @State private var toast: String?
    @State private var loading = true
    @State private var showLanternGallery = false

    // Space-dark night sky — warm navy, never cold sci-fi black. The old ink
    // roles flip to warm creams so every label reads against the dark.
    private let space = Color(hex: "#161C2E")
    private let spaceDeep = Color(hex: "#0E1220")
    private let ink = Color(hex: "#F2EEE3")
    private let ink2 = Color(hex: "#BFB9AA")
    private let ink3 = Color(hex: "#8C8779")
    private let sage = Color(hex: "#7BA872")
    private let peach = Color(hex: "#F5C6AA")

    private var todayKey: String { WorldMoodService.todayKey() }

    /// The user's own mood logged today — powers the local echo firefly so the
    /// world never feels empty to someone who just joined it.
    private var todaysOwnMood: EmotionalWeather? {
        SharedDataManager.shared.moodEntries
            .first(where: { Calendar.current.isDateInToday($0.date) })?
            .weatherType
    }
    private var selectedBucket: WorldDayBucket? { aggregate?.bucket(for: selectedDayKey) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [space, spaceDeep],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            WorldStarField()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    globeSection
                    warmTotalSection
                    findMyLightButton
                    dayChips
                    percentageSection
                    countryList
                    lanternSection
                    footer
                }
                .padding(.bottom, 28)
            }
            .defaultScrollAnchor(worldQAScrollBottom ? .bottom : .top)
        }
        .task {
            aggregate = await WorldMoodService.fetchAggregate()
            if selectedDayKey.isEmpty { selectedDayKey = todayKey }
            loading = false
        }
        .onAppear {
            AnalyticsManager.shared.trackWorldViewed()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-worldQAGallery") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showLanternGallery = true }
            }
            #endif
        }
    }

    private var worldQAScrollBottom: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-worldQAScrollBottom")
        #else
        return false
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("dino world")
                    .font(.custom(DinoTheme.customFontName, size: 24))
                    .foregroundColor(ink)
                // count moved to the constellation's warm total — the header
                // only speaks when the sky is empty or still loading
                if let line = headline {
                    Text(line)
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(ink3)
                }
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var headline: String? {
        guard let b = selectedBucket, b.global.total > 0 else {
            return loading ? "the world is waking up…" : "no lights yet today. yours could be the first \u{1F331}"
        }
        return nil   // deduped by owner call — the warm total is the headline now
    }

    // MARK: - Globe

    private var globeSection: some View {
        ZStack {
            // moonlit peach halo — fainter now, the lights are the heroes
            RadialGradient(colors: [peach.opacity(0.22), peach.opacity(0.0)],
                           center: .center, startRadius: 30, endRadius: 200)
                .frame(height: 360)
            WorldGlobeView(bucket: selectedBucket,
                           localEchoMood: todaysOwnMood,
                           localEchoCountry: WorldMoodService.countryCode(from: Locale.current.region?.identifier),
                           findMyLightTrigger: $findTrigger,
                           onFoundLight: { found in
                showToast(found ? "that's you 🦕" : "your light is glowing with the world 🌱")
            },
                           onGlowTap: { hit in
                guard let hit else { toast = nil; return }   // tap elsewhere dismisses
                if hit.isLocalEcho {
                    showToast("your light in \(countryName(hit.countryCode)) \(hit.mood.emoji)")
                } else {
                    showToast("dinos in \(countryName(hit.countryCode)) \(hit.mood.emoji)")
                }
            })
            .frame(height: 340)

            if let toast {
                Text(toast)
                    .font(DinoTheme.dinoFont(size: 14))
                    .foregroundColor(ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: "#232B42").opacity(0.95)))
                    .shadow(color: .black.opacity(0.30), radius: 6, y: 2)
                    .offset(y: 130)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .allowsHitTesting(false)   // never steal touches from the globe
            }
        }
        .animation(.easeInOut(duration: 0.25), value: toast)
    }

    private func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if toast == text { toast = nil }
        }
    }

    private var findMyLightButton: some View {
        Button {
            AnalyticsManager.shared.trackWorldFindMyLight()
            HapticManager.shared.light()
            if selectedDayKey != todayKey { selectedDayKey = todayKey }
            findTrigger += 1
        } label: {
            Text("find my light 🦕")
                .font(DinoTheme.dinoFont(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 22).padding(.vertical, 11)
                .background(Capsule().fill(sage))
                .shadow(color: sage.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Week rewind chips

    private var dayChips: some View {
        let keys = (aggregate?.sortedDayKeys ?? [todayKey]).sorted()   // oldest → newest
        return HStack(spacing: 8) {
            ForEach(keys, id: \.self) { key in
                let selected = key == selectedDayKey
                Button {
                    guard key != selectedDayKey else { return }
                    HapticManager.shared.light()
                    withAnimation(.easeInOut(duration: 0.25)) { selectedDayKey = key }
                    if key != todayKey { AnalyticsManager.shared.trackWorldRewindUsed() }
                } label: {
                    Text(chipLabel(key))
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(selected ? .white : ink2)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(selected ? sage : Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private func chipLabel(_ dayKey: String) -> String {
        if dayKey == todayKey { return "today" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        guard let date = df.date(from: dayKey) else { return dayKey }
        df.dateFormat = "EEE"
        return df.string(from: date).lowercased()
    }

    // MARK: - Percentages

    private var percentageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("the world's inner weather")
                .font(DinoTheme.dinoFont(size: 13))
                .foregroundColor(ink2)

            if let b = selectedBucket, b.global.total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(EmotionalWeather.allCases, id: \.self) { mood in
                            let w = geo.size.width * b.global.share(of: mood)
                            if w > 1 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DinoWorldPalette.moodSwiftUIColor(mood))
                                    .frame(width: max(w - 2, 2))
                            }
                        }
                    }
                }
                .frame(height: 14)

                HStack(spacing: 14) {
                    ForEach(EmotionalWeather.allCases, id: \.self) { mood in
                        let pct = Int((b.global.share(of: mood) * 100).rounded())
                        HStack(spacing: 4) {
                            Circle().fill(DinoWorldPalette.moodSwiftUIColor(mood)).frame(width: 7, height: 7)
                            Text("\(mood.label) \(pct)%")
                                .font(DinoTheme.dinoFont(size: 11))
                                .foregroundColor(ink2)
                        }
                    }
                }
            } else {
                Text("quiet skies so far. check back soon 🌿")
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(ink3)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.08)))
        .padding(.horizontal, 16)
    }

    // MARK: - Country list

    // MARK: - The number, directly under the globe (Change 1)

    @ViewBuilder private var warmTotalSection: some View {
        if let b = selectedBucket, b.global.total > 0 {
            VStack(spacing: 3) {
                (Text(WorldRedesignVoice.totalNumber(b.global.total))
                    .foregroundColor(Color(hex: "#f6da63"))
                 + Text(WorldRedesignVoice.totalSuffix(total: b.global.total,
                                                        isToday: selectedDayKey == todayKey))
                    .foregroundColor(Color(hex: "#ede8d6")))
                    .font(.custom(DinoTheme.customFontName, size: 27))
                    .shadow(color: Color(hex: "#f6da63").opacity(0.45), radius: 10)
                    .multilineTextAlignment(.center)
                Text(WorldConstellationVoice.subLine(countries: b.countries.count))
                    .font(DinoTheme.dinoFont(size: 13))
                    .foregroundColor(Color(hex: "#9aa0cc"))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
    }

    private var countryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let b = selectedBucket, !b.countries.isEmpty {
                WorldCountryList(bucket: b,
                                 isToday: selectedDayKey == todayKey,
                                 countryName: countryName)
            }
        }
        .padding(.horizontal, 24)
    }

    private func countryName(_ code: String) -> String {
        if code == "elsewhere" { return "elsewhere 🌎" }
        return (Locale.current.localizedString(forRegionCode: code) ?? code).lowercased()
    }

    // MARK: - Your lanterns 🏮

    /// The lanterns the grid/gallery show — real data, except under the
    /// `-worldQALanterns` screenshot arg, where non-persisting fixtures with
    /// distinct ids (so their seeded glows differ) stand in.
    private var worldLanterns: [ReceivedLantern] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-worldQALanterns") {
            return WorldMoodService.debugLanternFixtures()
        }
        #endif
        return SharedDataManager.shared.receivedLanterns
    }

    @ViewBuilder private var lanternSection: some View {
        let dm = SharedDataManager.shared
        let lanterns = worldLanterns
        if !lanterns.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                WorldLanternGrid(lanterns: lanterns) {
                    AnalyticsManager.shared.trackWorldLanternGalleryOpened()
                    showLanternGallery = true
                }

                if dm.sentLanternCount > 0 {
                    Text("you've sent \(dm.sentLanternCount) lantern\(dm.sentLanternCount == 1 ? "" : "s") into the world")
                        .font(DinoTheme.dinoFont(size: 12))
                        .foregroundColor(ink2)
                        .padding(.horizontal, 16)
                }
            }
            .fullScreenCover(isPresented: $showLanternGallery) {
                LanternGalleryView(lanterns: lanterns)
            }
        } else if dm.sentLanternCount > 0 {
            Text("you've sent \(dm.sentLanternCount) lantern\(dm.sentLanternCount == 1 ? "" : "s") into the world")
                .font(DinoTheme.dinoFont(size: 12))
                .foregroundColor(ink2)
                .padding(.horizontal, 16)
        }
    }

    private var footer: some View {
        Text("anonymous always. just moods and countries, never names or places.")
            .font(DinoTheme.dinoFont(size: 11))
            .foregroundColor(ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.top, 6)
    }
}

// MARK: - Pulsing list dot

struct WorldPulseDot: View {
    let color: Color
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .scaleEffect(on ? 1.25 : 0.85)
            .opacity(on ? 1.0 : 0.65)
            .animation(.easeInOut(duration: Double.random(in: 0.9...1.5)).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}
