//
//  F1RecDeliveryUITests.swift
//  DinoUITests
//
//  Rec delivery F1 — screenshot verification. The mood screen is pure
//  check-in (no rec surfaces), the little shelf lives on profile. Walker
//  pattern: soft-fail, screenshot what is on screen and move on. Dark mode
//  for test04 is set externally (simctl ui appearance dark) before the run.
//

import XCTest

final class F1RecDeliveryUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func makeApp(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenLetter", "YES", "-hasPassedAuth", "YES"] + extra
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @discardableResult
    private func tap(_ app: XCUIApplication, _ label: String, wait: TimeInterval = 2) -> Bool {
        let pred = NSPredicate(format: "label CONTAINS %@", label)
        for q in [app.buttons.matching(pred).firstMatch,
                  app.staticTexts.matching(pred).firstMatch,
                  app.otherElements.matching(pred).firstMatch] {
            if q.waitForExistence(timeout: wait), q.isHittable { q.tap(); return true }
        }
        return false
    }

    /// A gentle third-of-a-screen scroll — full swipes overshoot the row.
    private func smallScroll(_ app: XCUIApplication) {
        let s = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let e = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        s.press(forDuration: 0.05, thenDragTo: e)
        sleep(1)
    }

    /// Scroll the profile page in small steps until the shelf row sits fully
    /// on screen; returns it (or nil after 12 tries — soft-fail).
    private func findShelfRow(_ app: XCUIApplication) -> XCUIElement? {
        let pred = NSPredicate(format: "label CONTAINS %@", "little shelf")
        for _ in 0..<12 {
            let el = [app.buttons.matching(pred).firstMatch,
                      app.staticTexts.matching(pred).firstMatch]
                .first { $0.exists }
            if let el, el.frame.minY > app.frame.height * 0.05,
               el.frame.maxY < app.frame.height * 0.88 {
                return el
            }
            smallScroll(app)
        }
        return nil
    }

    // MARK: - 01 the mood screen reads as pure check-in
    func test01MoodClean() throws {
        let app = makeApp(["-moodTabQA"])
        app.launch()
        sleep(5)
        snap(app, "f1-mood-clean")
        app.swipeUp()
        sleep(1)
        snap(app, "f1-mood-clean-scrolled")
        app.terminate()
    }

    // MARK: - 02 profile carries the shelf row
    func test02ProfileRow() throws {
        let app = makeApp(["-profileTabQA"])
        app.launch()
        sleep(5)
        _ = findShelfRow(app)
        sleep(1)
        snap(app, "f1-profile-row")
        app.terminate()
    }

    // MARK: - 03 the shelf opens from profile (seeded, then a real tap)
    func test03ShelfFromProfile() throws {
        // seed a full shelf first — seedQAKeepsakes persists in defaults
        let seeder = makeApp(["-richRecQA3"])
        seeder.launch()
        sleep(6)
        seeder.terminate()
        sleep(2)

        let app = makeApp(["-profileTabQA"])
        app.launch()
        sleep(5)
        snap(app, "f1-shelf-debug-before-tap")
        if let row = findShelfRow(app) {
            row.tap()
        }
        sleep(3)
        snap(app, "f1-shelf-from-profile")
        app.terminate()
    }

    // MARK: - 04 mood screen, dark mode (appearance set via simctl)
    func test04MoodCleanDark() throws {
        let app = makeApp(["-moodTabQA"])
        app.launch()
        sleep(5)
        snap(app, "f1-mood-clean-dark")
        app.terminate()
    }
}
