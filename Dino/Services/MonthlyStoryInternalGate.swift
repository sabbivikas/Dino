import SwiftUI

struct MonthlyStoryInternalGate: Equatable, Sendable {
    let isEnabled: Bool

    static let disabled = MonthlyStoryInternalGate(isEnabled: false)

    static var processDefault: MonthlyStoryInternalGate {
        #if DEBUG
        return MonthlyStoryInternalGate(
            isEnabled: ProcessInfo.processInfo.arguments.contains("-monthlyStoryInternal")
        )
        #else
        return .disabled
        #endif
    }

    func permits(remoteVisible: Bool) -> Bool {
        isEnabled && remoteVisible
    }
}

private struct MonthlyStoryInternalGateKey: EnvironmentKey {
    static let defaultValue = MonthlyStoryInternalGate.processDefault
}

extension EnvironmentValues {
    var monthlyStoryInternalGate: MonthlyStoryInternalGate {
        get { self[MonthlyStoryInternalGateKey.self] }
        set { self[MonthlyStoryInternalGateKey.self] = newValue }
    }
}
