//
//  ShelfStatesUITests.swift
//  DinoUITests
//
//  Memory + shelf arc F4 — screenshot the full-archive shelf states
//  (mixed grid, kept filter, late keep). Soft-fail: screenshot what is
//  on screen and move on.
//

import XCTest

final class ShelfStatesUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

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
                  app.staticTexts.matching(pred).firstMatch] {
            if q.waitForExistence(timeout: wait), q.isHittable { q.tap(); return true }
        }
        return false
    }

    func testShelfStates() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-richRecQA3"]
        app.launch()
        sleep(6)
        tap(app, "little shelf", wait: 4)
        sleep(3)
        snap(app, "shelf-grid-everything")
        if tap(app, "kept") { sleep(2); snap(app, "shelf-filter-kept") }
        tap(app, "everything")
        sleep(1)
        if tap(app, "keep this") { sleep(2); snap(app, "shelf-after-keep-this") }
        app.terminate()
    }
}
