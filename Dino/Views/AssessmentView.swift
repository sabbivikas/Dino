//
//  AssessmentView.swift
//  Dino
//
//  Deprecated forwarding shim — the real implementation lives in
//  WeeklyCheckInView. Kept so older call sites keep compiling.
//

import SwiftUI

struct AssessmentView: View {
    @EnvironmentObject var dataManager: SharedDataManager

    var body: some View {
        WeeklyCheckInView()
            .environmentObject(dataManager)
    }
}
