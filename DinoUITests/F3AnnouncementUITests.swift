//
//  F3AnnouncementUITests.swift
//  DinoUITests
//
//  Rec delivery F3 QA helpers — not policy tests. These drive the app into
//  states the QA pass screenshots from outside (simctl cannot grant
//  notification permission, so a test taps the system alert once; a second
//  test raises the parcel live activity via the -recParcelQA hook).
//

import XCTest

final class F3AnnouncementUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    /// Taps "Allow" on the notification permission alert (fresh installs
    /// prompt on first launch). Harmless when already decided.
    func testGrantNotificationPermissionQA() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenLetter", "YES", "-hasPassedAuth", "YES"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) {
            allow.tap()
            sleep(2)
        }
        app.terminate()
    }

    /// Raises the parcel live activity through the -recParcelQA debug hook,
    /// then leaves the app running so the shell can lock / background the
    /// simulator and capture the lock screen + dynamic island presentations.
    func testStartRecParcelQA() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenLetter", "YES", "-hasPassedAuth", "YES", "-recParcelQA"]
        app.launch()
        sleep(6)   // let the activity register with the system
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "f3-app-after-parcel-start"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Raises the parcel, then presses the (simulator) lock button and holds
    /// the locked state for ~20s so the shell can screenshot the lock-screen
    /// live activity presentation from outside. QA-only — the private
    /// pressLockButton selector exists on simulators.
    func testLockScreenParcelQA() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenLetter", "YES", "-hasPassedAuth", "YES", "-recParcelQA"]
        app.launch()
        sleep(6)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(2)
        // first parcel ever → the system asks "Allow Live Activities from
        // Dino?" on the lock screen; answer it so the capture is clean
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        sleep(20)   // capture window for the external screenshot
    }
}
