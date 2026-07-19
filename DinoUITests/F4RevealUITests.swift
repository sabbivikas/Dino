//
//  F4RevealUITests.swift
//  DinoUITests
//
//  Rec delivery F4 — screenshot verification of the reveal moment. Walker
//  pattern: soft-fail, screenshot what is on screen and move on. Dark mode
//  for the dark shot is set externally (simctl ui appearance dark). The
//  -recRevealQA* hooks present the cover ~1.5s after launch with fixtures
//  (qa- ids write nothing).
//

import XCTest

final class F4RevealUITests: XCTestCase {

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

    /// Tap dead center — the whole wrapped screen unwraps the parcel.
    private func tapCenter(_ app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
    }

    // MARK: - 01 film case: parcel → mid-unwrap → image-led card
    func test01FilmReveal() throws {
        let app = makeApp(["-recRevealQA"])
        app.launch()
        sleep(4)   // launch + the 1.5s cover delay + artwork pre-warm
        snap(app, "f4-parcel-presented")
        tapCenter(app)
        usleep(350_000)   // ~mid-fold
        snap(app, "f4-unwrap-mid")
        sleep(3)          // card bloom + any late artwork fade
        snap(app, "f4-card-film")
        app.terminate()
    }

    // MARK: - 02 paper-only fallback (film without a poster — zero network)
    func test02PaperOnlyReveal() throws {
        let app = makeApp(["-recRevealQAPaper"])
        app.launch()
        sleep(4)
        tapCenter(app)
        sleep(3)
        snap(app, "f4-card-paperonly")
        app.terminate()
    }

    // MARK: - 03 dark mode (appearance set via simctl before the run)
    func test03DarkReveal() throws {
        let app = makeApp(["-recRevealQA"])
        app.launch()
        sleep(4)
        tapCenter(app)
        sleep(3)
        snap(app, "f4-card-dark")
        app.terminate()
    }

    // MARK: - 04 reduce motion: tap fades straight to the card, no fold
    func test04ReduceMotionReveal() throws {
        let app = makeApp(["-recRevealQAReduceMotion"])
        app.launch()
        sleep(4)
        snap(app, "f4-reducemotion-parcel")
        tapCenter(app)
        sleep(2)
        snap(app, "f4-reducemotion")
        app.terminate()
    }

    // MARK: - 05 swipe-down while wrapped dismisses (parcel stays for later)
    func test05SwipeDownWhileWrapped() throws {
        let app = makeApp(["-recRevealQA"])
        app.launch()
        sleep(4)
        let s = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let e = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        s.press(forDuration: 0.05, thenDragTo: e)
        sleep(2)
        snap(app, "f4-dismissed-wrapped")
        app.terminate()
    }
}