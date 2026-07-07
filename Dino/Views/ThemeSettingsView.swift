//
//  ThemeSettingsView.swift
//  Dino
//

import SwiftUI
import CoreLocation

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var weatherService: WeatherService
    @Environment(\.dismiss) private var dismiss
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined

    private let manualThemes = DinoAppTheme.allCases.filter { !$0.isWeatherOnly }
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    init() {
        _weatherService = StateObject(wrappedValue: WeatherService(themeManager: ThemeManager.shared))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mode picker
                modePicker

                // Content based on mode
                if themeManager.themeMode == .manual {
                    manualGrid
                } else {
                    weatherPanel
                }
            }
            .padding(DinoTheme.padding)
        }
        .background(DinoTheme.background.ignoresSafeArea())
        .navigationTitle("appearance")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            updateLocationStatus()
        }
        .onDisappear {
            // If the user backs out without applying, revert the preview
            if themeManager.previewTheme != nil {
                themeManager.cancelPreview()
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("theme mode")
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)
                .textCase(nil)

            HStack(spacing: 12) {
                ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                    ModeButton(
                        title: mode.displayName,
                        icon: mode == .manual ? "paintpalette" : "cloud.sun",
                        isSelected: themeManager.themeMode == mode
                    ) {
                        // Cancel any active preview before switching modes
                        themeManager.cancelPreview()
                        themeManager.themeMode = mode
                        if mode == .weather {
                            weatherService.requestLocation()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Manual Grid

    private var manualGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("choose a theme")
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)
                .textCase(nil)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(manualThemes) { theme in
                    ThemePreviewCard(
                        theme: theme,
                        isApplied: themeManager.selectedManualTheme == theme && themeManager.previewTheme == nil,
                        isPreviewing: themeManager.previewTheme == theme
                    ) {
                        themeManager.startPreview(theme)
                    }
                }
            }

            // Apply / Cancel buttons — shown when a preview is active
            if themeManager.previewTheme != nil {
                previewActionButtons
            }
        }
    }

    // MARK: - Preview Action Buttons

    private var previewActionButtons: some View {
        VStack(spacing: 10) {
            // Apply
            Button {
                themeManager.applyPreview()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(DinoTheme.subheadlineFont())
                    Text("apply theme")
                        .font(DinoTheme.bodyFont())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DinoTheme.accent)
                .cornerRadius(DinoTheme.cornerRadius)
            }
            .buttonStyle(ScaleButtonStyle())

            // Cancel
            Button {
                themeManager.cancelPreview()
            } label: {
                Text("cancel")
                    .font(DinoTheme.bodyFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DinoTheme.cardBackground)
                    .cornerRadius(DinoTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                            .stroke(DinoTheme.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.2), value: themeManager.previewTheme != nil)
    }

    // MARK: - Weather Panel

    private var weatherPanel: some View {
        VStack(spacing: 16) {
            // Info note: in weather mode the theme isn't manually choosable
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(DinoTheme.subheadlineFont())
                    .foregroundColor(DinoTheme.accent)
                Text("theme is controlled by weather. switch to manual to choose your own.")
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(DinoTheme.cardBackground)
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .stroke(DinoTheme.cardBorder, lineWidth: 1)
            )

            if locationStatus == .denied || locationStatus == .restricted {
                locationDeniedView
            } else {
                weatherStatusCard
            }
        }
    }

    private var weatherStatusCard: some View {
        VStack(spacing: 16) {
            // Current condition display
            VStack(spacing: 8) {
                Image(systemName: weatherIcon)
                    .font(.system(size: 44))
                    .foregroundColor(DinoTheme.accent)

                if themeManager.isLoadingWeather {
                    Text("checking weather...")
                        .font(DinoTheme.bodyFont())
                        .foregroundColor(DinoTheme.textSecondary)
                } else if let condition = themeManager.weatherCondition {
                    Text(condition)
                        .font(DinoTheme.headlineFont())
                        .foregroundColor(DinoTheme.textPrimary)

                    Text("theme: \(themeManager.currentTheme.displayName)")
                        .font(DinoTheme.subheadlineFont())
                        .foregroundColor(DinoTheme.textSecondary)
                } else {
                    Text("tap refresh to load weather")
                        .font(DinoTheme.bodyFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .dinoCard()

            // Apple requires visible attribution wherever weather appears —
            // quiet, tappable, links to their legal page.
            Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 9))
                    Text("Apple Weather")
                        .font(DinoTheme.dinoFont(size: 10))
                }
                .foregroundColor(DinoTheme.textSecondary.opacity(0.7))
            }

            // Refresh button
            Button {
                weatherService.requestLocation()
            } label: {
                HStack(spacing: 8) {
                    if themeManager.isLoadingWeather {
                        ProgressView()
                            .tint(Color.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(themeManager.isLoadingWeather ? "loading..." : "refresh")
                        .font(DinoTheme.bodyFont())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(DinoTheme.accent)
                .cornerRadius(DinoTheme.cornerRadius)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(themeManager.isLoadingWeather)

            // Weather-only theme preview (display only — no tap)
            VStack(alignment: .leading, spacing: 12) {
                Text("weather themes")
                    .font(DinoTheme.captionFont())
                    .foregroundColor(DinoTheme.textSecondary)
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    ForEach(DinoAppTheme.allCases.filter { $0.isWeatherOnly }) { theme in
                        ThemePreviewCard(
                            theme: theme,
                            isApplied: themeManager.currentTheme == theme,
                            isPreviewing: false,
                            onTap: nil
                        )
                    }
                }
            }
        }
    }

    private var locationDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 44))
                .foregroundColor(DinoTheme.textSecondary)

            Text("location access needed")
                .font(DinoTheme.headlineFont())
                .foregroundColor(DinoTheme.textPrimary)

            Text("allow location access so dino can match its theme to the weather around you.")
                .font(DinoTheme.subheadlineFont())
                .foregroundColor(DinoTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("open settings")
                    .font(DinoTheme.bodyFont())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(DinoTheme.accent)
                    .cornerRadius(DinoTheme.cornerRadius)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .dinoCard()
    }

    // MARK: - Helpers

    private var weatherIcon: String {
        guard let condition = themeManager.weatherCondition else { return "cloud.sun.fill" }
        let lower = condition.lowercased()
        if lower.contains("clear") || lower.contains("sunny") { return "sun.max.fill" }
        if lower.contains("rain") || lower.contains("drizzle") { return "cloud.rain.fill" }
        if lower.contains("thunder") || lower.contains("storm") { return "cloud.bolt.rain.fill" }
        if lower.contains("snow") { return "snowflake" }
        if lower.contains("cloud") { return "cloud.fill" }
        return "cloud.sun.fill"
    }

    private func updateLocationStatus() {
        locationStatus = CLLocationManager().authorizationStatus
    }
}

// MARK: - Mode Button

private struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(DinoTheme.dinoFont(size: 18))
                Text(title)
                    .font(DinoTheme.captionFont())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(isSelected ? .white : DinoTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? DinoTheme.accent : DinoTheme.cardBackground)
            .cornerRadius(DinoTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                    .stroke(isSelected ? DinoTheme.accent : DinoTheme.divider, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: DinoAppTheme
    /// True when this is the currently applied/saved theme (show checkmark badge)
    let isApplied: Bool
    /// True when this is the theme currently being previewed (show highlighted border)
    let isPreviewing: Bool
    var onTap: (() -> Void)?

    var body: some View {
        let colors = theme.colors

        Button {
            onTap?()
        } label: {
            VStack(spacing: 6) {
                // Color preview swatch
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: [colors.gradientTop, colors.gradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack(spacing: 4) {
                        Circle()
                            .fill(colors.accent)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(colors.secondary)
                            .frame(width: 10, height: 10)
                    }

                    // Checkmark badge — applied theme
                    if isApplied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DinoTheme.subheadlineFont())
                            .foregroundColor(colors.accent)
                            .background(Circle().fill(Color.white).padding(1))
                            .padding(5)
                    }
                }
                .frame(height: 52)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isPreviewing ? colors.accent :
                            isApplied    ? colors.accent.opacity(0.6) :
                                           Color.clear,
                            lineWidth: isPreviewing ? 2.5 : 1.5
                        )
                )

                Text(theme.displayName)
                    .font(DinoTheme.captionFont())
                    .foregroundColor(isPreviewing ? DinoTheme.textPrimary : DinoTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(
                isPreviewing ? colors.accent.opacity(0.15) :
                isApplied    ? colors.accent.opacity(0.08) :
                               Color.clear
            )
            .cornerRadius(DinoTheme.cornerRadius)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(onTap == nil)
    }
}
