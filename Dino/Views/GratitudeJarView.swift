//
//  GratitudeJarView.swift
//  Dino
//

import SwiftUI

// MARK: - Gratitude Icon Type
// Each saved note becomes one of three cute icons inside the jar
enum GratitudeIconType: Int, CaseIterable {
    case heart = 0
    case leaf = 1
    case dino = 2
    
    var emoji: String {
        switch self {
        case .heart: return "🧡"
        case .leaf: return "🍃"
        case .dino: return "🦕"
        }
    }
}

struct GratitudeJarView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    @EnvironmentObject var dataManager: SharedDataManager
    @StateObject private var viewModel: GratitudeViewModel = GratitudeViewModel(dataManager: SharedDataManager.shared)
    @State private var newDropIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                DinoTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Gratitude Jar")
                            .font(DinoTheme.dinoDisplayFont(size: 28))
                            .foregroundColor(DinoTheme.textPrimary)

                        Text("Take a moment to reflect on grateful moments\nevery day. Let's bring positivity into our lives\nwith gratitude journaling!")
                            .font(DinoTheme.dinoFont(size: 14))
                            .foregroundColor(DinoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // Jar
                    DinoJarView(
                        notes: viewModel.notes,
                        newDropIndex: newDropIndex,
                        onNoteTap: { note in viewModel.selectNote(note) }
                    )
                    .frame(height: 340)
                    .padding(.horizontal, 40)

                    // Count badge
                    ZStack {
                        Circle()
                            .fill(DinoTheme.surfacePrimary)
                            .frame(width: 48, height: 48)
                            .shadow(color: DinoTheme.shadowColor, radius: 8, y: 2)

                        Text("\(viewModel.totalCount)")
                            .font(DinoTheme.dinoFont(size: 18))
                            .foregroundColor(DinoTheme.textPrimary)
                    }
                    .padding(.top, 12)

                    // Today's progress
                    HStack(spacing: 4) {
                        Text("\(viewModel.todayCount)")
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(viewModel.todayCount >= viewModel.dailyGoal ? DinoTheme.sageGreen : DinoTheme.peach)
                        Text("of \(viewModel.dailyGoal) today")
                            .font(DinoTheme.dinoFont(size: 13))
                            .foregroundColor(DinoTheme.textSecondary)
                    }
                    .padding(.top, 6)

                    // Congratulations
                    if viewModel.showCongrats {
                        HStack(spacing: 8) {
                            Text("🎉")
                            Text("30 notes milestone!")
                                .font(DinoTheme.dinoFont(size: 14))
                                .foregroundColor(DinoTheme.peach)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(DinoTheme.peach.opacity(0.15))
                        .cornerRadius(20)
                        .padding(.top, 10)
                    }

                    Spacer()

                    // Write Gratitude button
                    Button {
                        viewModel.showAddSheet = true
                    } label: {
                        Text("Write Gratitude")
                            .font(DinoTheme.dinoFont(size: 17))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(DinoTheme.sageGreen)
                            )
                            .shadow(color: DinoTheme.sageGreen.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal, DinoTheme.padding)
                    .padding(.bottom, 16)
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddGratitudeSheet(viewModel: viewModel, onSaved: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        newDropIndex = viewModel.notes.count - 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        newDropIndex = nil
                    }
                })
            }
            .sheet(isPresented: $viewModel.showNoteDetail) {
                if let note = viewModel.selectedNote {
                    GratitudeNoteDetail(note: note)
                }
            }
            .onChange(of: dataManager.presentAddGratitude) { _, newValue in
                if newValue {
                    viewModel.showAddSheet = true
                    dataManager.presentAddGratitude = false
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Dino Jar View (matching the sketch)

struct DinoJarView: View {
    let notes: [GratitudeNote]
    let newDropIndex: Int?
    let onNoteTap: (GratitudeNote) -> Void

    var body: some View {
        GeometryReader { geo in
            let jarWidth = geo.size.width
            let jarHeight = geo.size.height

            ZStack {
                // Jar body
                JarShape()
                    .fill(DinoTheme.surfaceElevated.opacity(0.92))
                
                JarShape()
                    .stroke(Color(hex: "#2C2C2C"), lineWidth: 3.5)

                // Glass shine effect (left side)
                Path { path in
                    let x = jarWidth * 0.22
                    path.move(to: CGPoint(x: x, y: jarHeight * 0.25))
                    path.addCurve(
                        to: CGPoint(x: x - 4, y: jarHeight * 0.65),
                        control1: CGPoint(x: x - 8, y: jarHeight * 0.35),
                        control2: CGPoint(x: x + 4, y: jarHeight * 0.55)
                    )
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 3)

                // Green dotted fabric around neck
                JarFabricView()
                    .frame(width: jarWidth, height: jarHeight)

                // Lid
                JarLidView()
                    .frame(width: jarWidth, height: jarHeight)

                // Icons inside the jar
                JarContentsView(
                    notes: notes,
                    jarWidth: jarWidth,
                    jarHeight: jarHeight,
                    newDropIndex: newDropIndex,
                    onNoteTap: onNoteTap
                )
            }
        }
    }
}

// MARK: - Jar Shape

struct JarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        var path = Path()
        
        // Neck (top narrow part)
        let neckLeft = w * 0.28
        let neckRight = w * 0.72
        let neckTop = h * 0.12
        let shoulderY = h * 0.22
        
        // Body
        let bodyLeft = w * 0.12
        let bodyRight = w * 0.88
        let bottomY = h * 0.88
        let bottomRadius: CGFloat = 20
        
        path.move(to: CGPoint(x: neckLeft, y: neckTop))
        
        // Left side: neck → shoulder → body
        path.addCurve(
            to: CGPoint(x: bodyLeft, y: h * 0.35),
            control1: CGPoint(x: neckLeft - 6, y: shoulderY),
            control2: CGPoint(x: bodyLeft, y: h * 0.28)
        )
        
        // Left body straight
        path.addLine(to: CGPoint(x: bodyLeft, y: bottomY - bottomRadius))
        
        // Bottom left corner
        path.addQuadCurve(
            to: CGPoint(x: bodyLeft + bottomRadius, y: bottomY),
            control: CGPoint(x: bodyLeft, y: bottomY)
        )
        
        // Bottom
        path.addLine(to: CGPoint(x: bodyRight - bottomRadius, y: bottomY))
        
        // Bottom right corner
        path.addQuadCurve(
            to: CGPoint(x: bodyRight, y: bottomY - bottomRadius),
            control: CGPoint(x: bodyRight, y: bottomY)
        )
        
        // Right body straight
        path.addLine(to: CGPoint(x: bodyRight, y: h * 0.35))
        
        // Right side: body → shoulder → neck
        path.addCurve(
            to: CGPoint(x: neckRight, y: neckTop),
            control1: CGPoint(x: bodyRight, y: h * 0.28),
            control2: CGPoint(x: neckRight + 6, y: shoulderY)
        )
        
        return path
    }
}

// MARK: - Jar Fabric (green dotted band)

struct JarFabricView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let fabricY = h * 0.17
            
            ZStack {
                // Main fabric band
                Path { path in
                    let left = w * 0.22
                    let right = w * 0.78
                    path.move(to: CGPoint(x: left, y: fabricY))
                    path.addLine(to: CGPoint(x: right, y: fabricY))
                    path.addLine(to: CGPoint(x: right + 10, y: fabricY + 14))
                    // Scalloped bottom edge
                    let steps = 6
                    let stepWidth = (right + 10 - (left - 10)) / CGFloat(steps)
                    for i in 0..<steps {
                        let xStart = right + 10 - CGFloat(i) * stepWidth
                        let xEnd = xStart - stepWidth
                        let midX = (xStart + xEnd) / 2
                        path.addQuadCurve(
                            to: CGPoint(x: xEnd, y: fabricY + 14),
                            control: CGPoint(x: midX, y: fabricY + 24)
                        )
                    }
                    path.closeSubpath()
                }
                .fill(Color(hex: "#4CAF7D").opacity(0.75))
                
                // Dots pattern on fabric
                ForEach(0..<8, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: "#3D9669").opacity(0.5))
                        .frame(width: 3, height: 3)
                        .offset(
                            x: -w * 0.2 + CGFloat(i) * (w * 0.5 / 8),
                            y: fabricY - geo.size.height / 2 + 7
                        )
                }
            }
        }
    }
}

// MARK: - Jar Lid

struct JarLidView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let lidY = h * 0.06
            
            // Lid
            ZStack {
                // Lid body
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#A0A0A0"), Color(hex: "#888888"), Color(hex: "#A8A8A8")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: w * 0.5, height: h * 0.07)
                    .position(x: w * 0.5, y: lidY + h * 0.035)
                
                // Lid outline
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color(hex: "#2C2C2C"), lineWidth: 2.5)
                    .frame(width: w * 0.5, height: h * 0.07)
                    .position(x: w * 0.5, y: lidY + h * 0.035)
                
                // Small bumps on lid edge
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: "#2C2C2C"))
                        .frame(width: 4, height: 4)
                        .position(
                            x: w * 0.35 + CGFloat(i) * w * 0.15,
                            y: lidY + h * 0.065
                        )
                }
            }
        }
    }
}

// MARK: - Jar Contents (icons inside)

struct JarContentsView: View {
    let notes: [GratitudeNote]
    let jarWidth: CGFloat
    let jarHeight: CGFloat
    let newDropIndex: Int?
    let onNoteTap: (GratitudeNote) -> Void

    var body: some View {
        let displayNotes = Array(notes.prefix(30))
        
        ForEach(Array(displayNotes.enumerated()), id: \.element.id) { i, note in
            let iconType = GratitudeIconType(rawValue: i % 3) ?? .heart
            let pos = iconPosition(index: i, total: displayNotes.count)
            let isNew = newDropIndex == i
            
            Button {
                onNoteTap(note)
            } label: {
                JarIcon(type: iconType)
            }
            .buttonStyle(.plain)
            .position(x: jarWidth * pos.x, y: jarHeight * pos.y)
            .rotationEffect(.degrees(iconRotation(index: i)))
            .offset(y: isNew ? -200 : 0)
            .animation(
                isNew ? .spring(response: 0.6, dampingFraction: 0.5).delay(0.1) : .default,
                value: isNew
            )
        }
    }

    private func iconPosition(index: Int, total: Int) -> (x: CGFloat, y: CGFloat) {
        // Fill from bottom up, scattered naturally
        let row = index / 4
        let col = index % 4
        
        let baseY: CGFloat = 0.82 - CGFloat(row) * 0.1
        let yJitter = CGFloat.random(in: -0.02...0.02)
        let y = max(0.35, min(baseY + yJitter, 0.85))
        
        let xPositions: [CGFloat] = [0.28, 0.42, 0.58, 0.72]
        let xJitter = CGFloat.random(in: -0.04...0.04)
        let x = xPositions[col] + xJitter
        
        return (x, y)
    }

    private func iconRotation(index: Int) -> Double {
        let rotations: [Double] = [-15, 8, -5, 12, -10, 3, -8, 15, -3, 10, -12, 5]
        return rotations[index % rotations.count]
    }
}

// MARK: - Jar Icon (heart / leaf / dino)

struct JarIcon: View {
    let type: GratitudeIconType

    var body: some View {
        Group {
            switch type {
            case .heart:
                HeartIcon()
            case .leaf:
                LeafIcon()
            case .dino:
                DinoIcon()
            }
        }
        .frame(width: 32, height: 32)
    }
}

// Orange heart with outline
struct HeartIcon: View {
    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .font(DinoTheme.dinoFont(size: 24))
                .foregroundColor(Color(hex: "#E8935A"))
            Image(systemName: "heart")
                .font(DinoTheme.dinoFont(size: 24))
                .foregroundColor(Color(hex: "#C47840"))
        }
    }
}

// Green leaf
struct LeafIcon: View {
    var body: some View {
        ZStack {
            Image(systemName: "leaf.fill")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(Color(hex: "#7DB86A"))
            Image(systemName: "leaf")
                .font(DinoTheme.dinoFont(size: 22))
                .foregroundColor(Color(hex: "#5A9648"))
        }
    }
}

// Cute mini dino
struct DinoIcon: View {
    var body: some View {
        Text("🦕")
            .font(DinoTheme.dinoFont(size: 22))
    }
}

// MARK: - Add Gratitude Sheet

struct AddGratitudeSheet: View {
    @ObservedObject var viewModel: GratitudeViewModel
    @FocusState private var focused: Bool
    var onSaved: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("add to your jar")
                        .font(DinoTheme.dinoFont(size: 22))
                        .foregroundColor(DinoTheme.textPrimary)
                    Text("what are you grateful for right now?")
                        .font(DinoTheme.dinoFont(size: 15))
                        .foregroundColor(DinoTheme.textSecondary)
                }
                .padding(.top, 8)

                ZStack(alignment: .topLeading) {
                    if viewModel.newNoteText.isEmpty {
                        Text("type something you're grateful for...")
                            .font(DinoTheme.bodyFont())
                            .foregroundColor(DinoTheme.textSecondary.opacity(0.6))
                            .padding(.top, 12)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $viewModel.newNoteText)
                        .font(DinoTheme.bodyFont())
                        .focused($focused)
                        .frame(height: 120)
                        .onChange(of: viewModel.newNoteText) { _, val in
                            if val.count > 200 {
                                viewModel.newNoteText = String(val.prefix(200))
                            }
                        }
                }
                .padding(12)
                .background(DinoTheme.cardBackground)
                .cornerRadius(DinoTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: DinoTheme.cornerRadius)
                        .stroke(DinoTheme.divider, lineWidth: 1)
                )

                HStack {
                    // Icon preview
                    HStack(spacing: 8) {
                        HeartIcon().frame(width: 20, height: 20).scaleEffect(0.7)
                        LeafIcon().frame(width: 20, height: 20).scaleEffect(0.7)
                        DinoIcon().frame(width: 20, height: 20).scaleEffect(0.7)
                    }
                    Spacer()
                    Text("\(viewModel.newNoteText.count)/200")
                        .font(DinoTheme.captionFont())
                        .foregroundColor(DinoTheme.textSecondary)
                }

                Button(action: {
                    viewModel.addNote()
                    onSaved?()
                }) {
                    Text("add to jar 🫙")
                        .font(DinoTheme.dinoFont(size: 17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            viewModel.newNoteText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.gray.opacity(0.3)
                                : DinoTheme.sageGreen
                        )
                        .cornerRadius(16)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(viewModel.newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.horizontal, DinoTheme.padding)
            .onAppear { focused = true }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel") {
                        viewModel.newNoteText = ""
                        viewModel.showAddSheet = false
                    }
                    .foregroundColor(DinoTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Note Detail Sheet

struct GratitudeNoteDetail: View {
    let note: GratitudeNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("🫙")
                .font(.system(size: 50))
                .padding(.top, 32)

            Text(note.text)
                .font(DinoTheme.dinoFont(size: 20))
                .foregroundColor(DinoTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(note.createdAt.formatted(date: .long, time: .omitted))
                .font(DinoTheme.captionFont())
                .foregroundColor(DinoTheme.textSecondary)

            Spacer()

            Button("close") { dismiss() }
                .font(DinoTheme.bodyFont())
                .foregroundColor(DinoTheme.textSecondary)
                .padding(.bottom, 32)
        }
    }
}
