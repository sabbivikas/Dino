//
//  F5ShelfCatchUITests.swift
//  DinoUITests
//
//  Rec delivery F5 — the shelf catch. Screenshot the mixed shelf (wrapped
//  parcels + opened thumbnails), a wrapped parcel's caption, and a tap
//  opening the F4 reveal. Soft-fail: shoot what is on screen and move on.
//

import XCTest

final class F5ShelfCatchUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @discardableResult
    private func tap(_ app: XCUIApplication, _ label: String, wait: TimeInterval = 3) -> Bool {
        let pred = NSPredicate(format: "label CONTAINS %@", label)
        for q in [app.buttons.matching(pred).firstMatch,
                  app.staticTexts.matching(pred).firstMatch,
                  app.otherElements.matching(pred).firstMatch] {
            if q.waitForExistence(timeout: wait), q.isHittable { q.tap(); return true }
        }
        return false
    }

    /// Mixed shelf: seeded opened keepsakes (-richRecQA3) + wrapped parcel
    /// fixtures (-recShelfWrappedQA), then a tap on a wrapped parcel to open
    /// the reveal.
    func testShelfCatchMixedAndTapOpensReveal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-richRecQA3", "-recShelfWrappedQA"]
        app.launch()
        sleep(6)
        tap(app, "little shelf", wait: 4)
        sleep(3)
        snap(app, "f5-shelf-mixed")
        // a wrapped parcel → the F4 reveal
        if tap(app, "still wrapped", wait: 4) {
            sleep(3)
            snap(app, "f5-tap-opens-reveal")
        }
        app.terminate()
    }

    /// Empty state still correct: no keepsakes, no wrapped parcels.
    func testShelfCatchEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-recShelfEmptyQA"]
        app.launch()
        sleep(6)
        snap(app, "f5-shelf-empty")
        app.terminate()
    }
}
