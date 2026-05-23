//
//  AssessmentView.swift
//  Dino
//
//  Thin host that presents the new WeeklyCheckInView. The legacy assessment
//  flow lived here previously — entry points (HomeView, ProfileView) still
//  push `AssessmentView()`, so we keep the name and just render the new view.
//

import SwiftUI

struct AssessmentView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    var body: some View {
        WeeklyCheckInView()
            .environmentObject(dataManager)
    }
}
