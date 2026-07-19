//
//  KoreanWalkUITests.swift
//  DinoUITests
//
//  Full-app localized screen walk. Launches the app in the walk language and
//  screenshots every screen/sheet/state reachable without a network or a
//  real account. Screenshots are exported from the xcresult afterwards.
//  Soft-fail philosophy: a missed tap must never kill the walk — screenshot
//  what is on screen and move on.
//

import XCTest

final class KoreanWalkUITests: XCTestCase {

    private let lang = ProcessInfo.processInfo.environment["WALK_LANG"] ?? "ko"
    private let loc = ProcessInfo.processInfo.environment["WALK_LOCALE"] ?? "ko_KR"

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func makeApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", loc] + extra
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @discardableResult
    private func tap(_ app: XCUIApplication, _ label: String, wait: TimeInterval = 3) -> Bool {
        // exact match first, then CONTAINS — composed accessibility labels
        // (icon + title + subtitle rows) defeat exact matching.
        let pred = NSPredicate(format: "label CONTAINS %@", label)
        for q in [app.buttons[label], app.staticTexts[label],
                  app.buttons.matching(pred).firstMatch,
                  app.staticTexts.matching(pred).firstMatch,
                  app.otherElements.matching(pred).firstMatch] {
            if q.waitForExistence(timeout: wait), q.isHittable { q.tap(); return true }
        }
        return false
    }

    /// Tap the bottom-most hittable button — onboarding primaries live at the
    /// bottom and this stays language-independent.
    @discardableResult
    private func tapBottomButton(_ app: XCUIApplication) -> Bool {
        let buttons = app.buttons.allElementsBoundByIndex.filter { $0.isHittable }
        guard let target = buttons.max(by: { $0.frame.midY < $1.frame.midY }) else { return false }
        target.tap()
        return true
    }

    private func dismissSheet(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.05, thenDragTo: end)
        sleep(1)
    }

    private func settle(_ seconds: UInt32 = 2) { sleep(seconds) }

    // MARK: - 01 first-launch letter (the typewriter)
    func test01Letter() throws {
        let app = makeApp(["-hasSeenLetter", "NO"])
        app.launch()
        // clear the ios notification-permission alert if it appears — it is
        // system-owned (device locale), not part of the localized walk.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 4) {
            let allow = springboard.alerts.buttons.element(boundBy: 1)
            if allow.exists { allow.tap() }
        }
        settle(2)
        snap(app, "letter-typing")
        settle(12)
        snap(app, "letter-full")
        app.terminate()
    }

    // MARK: - 02 sign-in
    func test02SignIn() throws {
        let app = makeApp(["-authQA", "-hasSeenLetter", "YES"])
        app.launch()
        settle(3)
        snap(app, "signin")
        if tap(app, "이메일") { settle(1); snap(app, "signin-email-form") }
        app.terminate()
    }

    // MARK: - 03 onboarding walk
    func test03Onboarding() throws {
        let app = makeApp(["-onboardingQA", "-hasSeenLetter", "YES", "-hasPassedAuth", "YES"])
        app.launch()
        settle(4)
        snap(app, "onboarding-step00-welcome")
        tapBottomButton(app)
        settle(2)
        for step in 1...14 {
            snap(app, String(format: "onboarding-step%02d", step))
            let pills = app.buttons.allElementsBoundByIndex.filter {
                $0.isHittable && $0.frame.midY > app.frame.height * 0.25
                    && $0.frame.midY < app.frame.height * 0.75
            }
            if let firstPill = pills.first, pills.count > 2 {
                firstPill.tap()
                settle(1)
                snap(app, String(format: "onboarding-step%02d-selected", step))
            }
            if !tapBottomButton(app) { break }
            settle(2)
        }
        app.terminate()
    }

    // MARK: - 04 main tabs + home sheets — fresh launch per destination so a
    // sticky sheet can never poison the rest of the walk.
    func test04MainWalk() throws {
        func freshLaunch(_ steps: (XCUIApplication) -> Void) {
            let app = makeApp()
            app.launch()
            settle(4)
            steps(app)
            app.terminate()
        }

        freshLaunch { app in self.snap(app, "home") }

        let homeActions: [(String, String)] = [
            ("호흡", "breathing"), ("명상", "meditation"), ("확언", "affirmations"),
            ("리듬", "rhythms"), ("성장", "growth"), ("세상", "world"),
        ]
        for (label, name) in homeActions {
            freshLaunch { app in
                if self.tap(app, label) {
                    self.settle(3)
                    self.snap(app, "home-\(name)")
                } else {
                    self.snap(app, "home-\(name)-NOTFOUND")
                }
            }
        }

        freshLaunch { app in
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.07)).tap()
            self.settle(2)
            self.snap(app, "notification-center")
        }

        let tabs: [(String, String)] = [
            ("일기", "journal"), ("기분", "mood"), ("항아리", "jar"), ("프로필", "profile"),
        ]
        for (label, name) in tabs {
            freshLaunch { app in
                // the tab bar exposes its korean labels — tap the LAST match
                // (grid tiles share some labels; the tab bar sits lowest)
                let pred = NSPredicate(format: "label CONTAINS %@", label)
                let matches = (app.buttons.matching(pred).allElementsBoundByIndex
                             + app.staticTexts.matching(pred).allElementsBoundByIndex)
                    .filter { $0.isHittable }
                if let tab = matches.max(by: { $0.frame.midY < $1.frame.midY }) {
                    tab.tap()
                }
                self.settle(3)
                self.snap(app, "tab-\(name)")
                app.swipeUp()
                self.settle(1)
                self.snap(app, "tab-\(name)-scrolled")
            }
        }

        let profileRows: [(String, String)] = [
            ("테마와 날씨", "theme-settings"),
            ("글자 크기", "text-size"),
            ("프로필 정보", "profile-details"),
            ("주간 체크인", "weekly-checkin"),
            ("도움말과 피드백", "feedback"),
            ("개인정보와 데이터", "privacy"),
        ]
        for (label, name) in profileRows {
            freshLaunch { app in
                let pred = NSPredicate(format: "label CONTAINS %@", "프로필")
                let matches = (app.buttons.matching(pred).allElementsBoundByIndex
                             + app.staticTexts.matching(pred).allElementsBoundByIndex)
                    .filter { $0.isHittable }
                matches.max(by: { $0.frame.midY < $1.frame.midY })?.tap()
                self.settle(2)
                var tapped = false
                for _ in 0..<5 {
                    if self.tap(app, label, wait: 1) { tapped = true; break }
                    app.swipeUp()
                    self.settle(1)
                }
                self.settle(2)
                self.snap(app, tapped ? "profile-\(name)" : "profile-\(name)-NOTFOUND")
            }
        }
    }

    // MARK: - 05 QA states — rec delivery F1: the mood screen is pure
    // check-in, so the rec-card / expedition / gift-reader mood hooks are
    // gone; the shelf state walks through the profile tab instead.
    func test05MoodStates() throws {
        let states: [(String, String, String)] = [
            ("-richRecQA3", "profile-keepsakes-shelf", "프로필"),
            ("-ceremonyQA", "mood-ceremony", "기분"),
            ("-resourcesQA", "mood-resources", "기분"),
            ("-moodStepsQA", "mood-mood-steps", "기분"),
        ]
        for (flag, name, tabLabel) in states {
            let app = makeApp([flag])
            app.launch()
            settle(5)
            // some hooks do not preselect the tab — tap it explicitly
            let pred = NSPredicate(format: "label CONTAINS %@", tabLabel)
            let matches = (app.buttons.matching(pred).allElementsBoundByIndex
                         + app.staticTexts.matching(pred).allElementsBoundByIndex)
                .filter { $0.isHittable }
            matches.max(by: { $0.frame.midY < $1.frame.midY })?.tap()
            settle(3)
            snap(app, name)
            app.swipeUp()
            settle(1)
            snap(app, "\(name)-scrolled")
            app.terminate()
        }
    }

    // MARK: - 06 profile sheets by index — SBRow labels are not exposed to
    // XCUITest, so tap every button on the profile page blindly and
    // screenshot whatever opens.
    func test06ProfileSheets() throws {
        for i in 0..<8 {
            let app = makeApp()
            app.launch()
            settle(4)
            let profPred = NSPredicate(format: "label CONTAINS %@", "프로필")
            let profMatches = (app.buttons.matching(profPred).allElementsBoundByIndex
                             + app.staticTexts.matching(profPred).allElementsBoundByIndex)
                .filter { $0.isHittable }
            profMatches.max(by: { $0.frame.midY < $1.frame.midY })?.tap()
            settle(2)
            app.swipeUp()
            settle(1)
            let buttons = app.buttons.allElementsBoundByIndex.filter {
                $0.isHittable && $0.frame.minY > app.frame.height * 0.12
                             && $0.frame.maxY < app.frame.height * 0.92
            }
            guard i < buttons.count else { app.terminate(); continue }
            buttons[i].tap()
            settle(3)
            snap(app, String(format: "profile-sheet-%02d", i))
            app.terminate()
        }
    }

    // MARK: - 07 residuals — ceremony timing, notification center, step02 layout
    func test07Residuals() throws {
        // ceremony: the choreography takes a while — capture a timeline
        let cer = makeApp(["-ceremonyQA"])
        cer.launch()
        settle(3)
        let pred = NSPredicate(format: "label CONTAINS %@", "기분")
        (cer.buttons.matching(pred).allElementsBoundByIndex
         + cer.staticTexts.matching(pred).allElementsBoundByIndex)
            .filter { $0.isHittable }
            .max(by: { $0.frame.midY < $1.frame.midY })?.tap()
        for t in [4, 8, 14, 20] {
            settle(UInt32(t <= 4 ? 4 : 6))
            snap(cer, "ceremony-t\(t)")
        }
        cer.terminate()

        // notification center: tap the actual bell button by frame (top strip,
        // right side) instead of a blind coordinate
        let app = makeApp()
        app.launch()
        settle(4)
        let topRight = app.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.midY < app.frame.height * 0.12
                          && $0.frame.midX > app.frame.width * 0.6
        }
        if let bell = topRight.max(by: { $0.frame.midX < $1.frame.midX }) {
            bell.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.075)).tap()
        }
        settle(3)
        snap(app, "notification-center-2")
        app.swipeUp()
        settle(1)
        snap(app, "notification-center-2-scrolled")
        app.terminate()

        // onboarding step02 (doing-great message) — recheck the left-edge clip
        // after animations settle
        let ob = makeApp(["-onboardingQA", "-hasSeenLetter", "YES", "-hasPassedAuth", "YES"])
        ob.launch()
        settle(4)
        tapBottomButton(ob)          // begin
        settle(2)
        // step 1: pick the first feeling pill (doing great) then advance
        let pills = ob.buttons.allElementsBoundByIndex.filter {
            $0.isHittable && $0.frame.midY > ob.frame.height * 0.25
                && $0.frame.midY < ob.frame.height * 0.75
        }
        pills.first?.tap()
        settle(1)
        tapBottomButton(ob)
        settle(6)                    // let the entrance animation fully settle
        snap(ob, "step02-settled")
        ob.terminate()
    }
}
