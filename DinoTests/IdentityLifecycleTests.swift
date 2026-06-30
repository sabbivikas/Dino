//
//  IdentityLifecycleTests.swift
//  DinoTests
//
//  Unit tests for the PostHog identity lifecycle. All Firebase/PostHog
//  dependencies are faked, and the 5s timeout is driven by a controllable
//  scheduler (fake timers), so these run fast and deterministically.
//

import XCTest
@testable import Dino

// MARK: - Fakes

private final class FakeIdentityClient: IdentityClient {
    enum Event: Equatable {
        case identify(String)
        case capture(String)
        case reset
    }
    private(set) var events: [Event] = []
    private(set) var captures: [(event: String, props: [String: Any])] = []

    func identify(_ distinctId: String, properties: [String: Any]) {
        events.append(.identify(distinctId))
    }
    func capture(_ event: String, properties: [String: Any]) {
        events.append(.capture(event))
        captures.append((event, properties))
    }
    func reset() {
        events.append(.reset)
    }

    var appOpenedCount: Int { events.filter { $0 == .capture("app_opened") }.count }
    func openType(at index: Int) -> String? {
        captures.filter { $0.event == "app_opened" }[index].props["open_type"] as? String
    }
}

/// Fires the scheduled work only when the test calls `fire()`.
private final class FakeScheduler: IdentityScheduler {
    private var pending: (() -> Void)?
    private(set) var cancelled = false
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> () -> Void {
        pending = work
        return { [weak self] in self?.cancelled = true; self?.pending = nil }
    }
    func fire() { pending?() }
}

/// Controllable auth source for resolver + late-recovery tests.
private final class FakeAuthSource {
    private(set) var callback: ((String?) -> Void)?
    private(set) var unsubscribed = false
    func subscribe(_ cb: @escaping (String?) -> Void) -> () -> Void {
        callback = cb
        return { [weak self] in self?.unsubscribed = true }
    }
    func emit(_ uid: String?) { callback?(uid) }
}

/// Resolver stub for manager tests (returns a preset result).
private final class FakeResolver: AuthUserResolving {
    let result: String?
    init(_ result: String?) { self.result = result }
    func resolve() async -> String? { result }
}

@MainActor
final class IdentityLifecycleTests: XCTestCase {

    private func makeManager(resolver: AuthUserResolving,
                             lateSource: FakeAuthSource,
                             firstOpen: Bool = false) -> (IdentityLifecycleManager, FakeIdentityClient) {
        let client = FakeIdentityClient()
        let manager = IdentityLifecycleManager(
            client: client,
            resolver: resolver,
            lateSubscribe: lateSource.subscribe,
            isFirstOpenProvider: { firstOpen },
            log: { _ in }
        )
        return (manager, client)
    }

    // MARK: Resolver (cases 1–4)

    // 1) Firebase auth resolves before the timeout.
    func testResolverResolvesBeforeTimeout() {
        let source = FakeAuthSource()
        let scheduler = FakeScheduler()
        let resolver = TimeoutAuthResolver(timeout: 5, scheduler: scheduler, subscribe: source.subscribe)

        var result: String?
        var calls = 0
        resolver.resolve { result = $0; calls += 1 }
        source.emit("uid-A")

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(result, "uid-A")
        XCTAssertTrue(scheduler.cancelled, "timeout should be cancelled once resolved")
        XCTAssertTrue(source.unsubscribed, "listener should be removed once resolved")
    }

    // 2) Firebase auth returns no user before the timeout.
    func testResolverReturnsNilBeforeTimeout() {
        let source = FakeAuthSource()
        let scheduler = FakeScheduler()
        let resolver = TimeoutAuthResolver(timeout: 5, scheduler: scheduler, subscribe: source.subscribe)

        var result: String? = "sentinel"
        var calls = 0
        resolver.resolve { result = $0; calls += 1 }
        source.emit(nil)

        XCTAssertEqual(calls, 1)
        XCTAssertNil(result)
        XCTAssertTrue(scheduler.cancelled)
    }

    // 3) Firebase auth resolves AFTER the timeout — the late callback is ignored.
    func testResolverResolvesAfterTimeout() {
        let source = FakeAuthSource()
        let scheduler = FakeScheduler()
        let resolver = TimeoutAuthResolver(timeout: 5, scheduler: scheduler, subscribe: source.subscribe)

        var result: String? = "sentinel"
        var calls = 0
        resolver.resolve { result = $0; calls += 1 }
        scheduler.fire()            // timeout wins
        source.emit("uid-late")     // arrives too late

        XCTAssertEqual(calls, 1, "completion must fire exactly once")
        XCTAssertNil(result, "timeout result (nil) must stand")
    }

    // 4) Timeout and auth callback happen close together — resolves only once.
    func testResolverSettlesOnlyOnce() {
        let source = FakeAuthSource()
        let scheduler = FakeScheduler()
        let resolver = TimeoutAuthResolver(timeout: 5, scheduler: scheduler, subscribe: source.subscribe)

        var calls = 0
        resolver.resolve { _ in calls += 1 }
        scheduler.fire()
        source.emit("uid")
        source.emit("uid-2")

        XCTAssertEqual(calls, 1)
    }

    // MARK: Cold start + foreground (cases 7, 8, 9)

    // 7) Logged-in cold launch identifies BEFORE capturing app_opened.
    func testColdStartIdentifiesBeforeAppOpened() async {
        let (manager, client) = makeManager(resolver: FakeResolver("uid-A"), lateSource: FakeAuthSource())
        await manager.handleColdStart()

        XCTAssertEqual(client.events, [.identify("uid-A"), .capture("app_opened")])
        XCTAssertEqual(client.openType(at: 0), "cold_start")
    }

    // 8) Foreground return captures open_type = foreground.
    func testForegroundReturnOpenType() async {
        let (manager, client) = makeManager(resolver: FakeResolver("uid-A"), lateSource: FakeAuthSource())
        await manager.handleColdStart()
        manager.handleForegroundReturn()

        XCTAssertEqual(client.appOpenedCount, 2)
        XCTAssertEqual(client.openType(at: 0), "cold_start")
        XCTAssertEqual(client.openType(at: 1), "foreground")
    }

    // 9) Repeated cold-start calls are blocked.
    func testRepeatedColdStartBlocked() async {
        let (manager, client) = makeManager(resolver: FakeResolver("uid-A"), lateSource: FakeAuthSource())
        await manager.handleColdStart()
        let countAfterFirst = client.events.count
        await manager.handleColdStart()

        XCTAssertEqual(client.events.count, countAfterFirst, "second cold start must be a no-op")
        XCTAssertEqual(client.appOpenedCount, 1)
    }

    // MARK: Late identity recovery (cases 5, 6)

    // 5) Late identity recovery calls identify exactly once.
    func testLateRecoveryIdentifiesOnce() async {
        let lateSource = FakeAuthSource()
        let (manager, client) = makeManager(resolver: FakeResolver(nil), lateSource: lateSource)
        await manager.handleColdStart()       // no user → anonymous + recovery armed

        XCTAssertEqual(client.events, [.capture("app_opened")])
        lateSource.emit("uid-A")              // user recovered
        lateSource.emit("uid-A")              // repeated — ignored

        XCTAssertEqual(client.events.filter { $0 == .identify("uid-A") }.count, 1)
        XCTAssertTrue(manager.lateIdentityRecoveryComplete)
        XCTAssertTrue(lateSource.unsubscribed, "recovery listener removed after success")
    }

    // 6) Late identity recovery does NOT create a second app_opened.
    func testLateRecoveryDoesNotCaptureAppOpened() async {
        let lateSource = FakeAuthSource()
        let (manager, client) = makeManager(resolver: FakeResolver(nil), lateSource: lateSource)
        await manager.handleColdStart()
        lateSource.emit("uid-A")

        XCTAssertEqual(client.appOpenedCount, 1, "recovery must not fire another app_opened")
    }

    // MARK: Logout (cases 10, 11, 12)

    // 10) Logout captures user_signed_out BEFORE calling reset().
    func testLogoutCapturesBeforeReset() async {
        let (manager, client) = makeManager(resolver: FakeResolver("uid-A"), lateSource: FakeAuthSource())
        manager.handleLogout()

        XCTAssertEqual(client.events, [.capture("user_signed_out"), .reset])
    }

    // 11) Logout calls reset() with no arguments.
    //     (Enforced at compile time: IdentityClient.reset() takes no parameters;
    //     there is no reset(Bool) overload to call.)
    func testLogoutResetTakesNoArgument() async {
        let (manager, client) = makeManager(resolver: FakeResolver("uid-A"), lateSource: FakeAuthSource())
        manager.handleLogout()

        XCTAssertTrue(client.events.contains(.reset))
    }

    // 12) A second account on the same device is not aliased to the previous one:
    //     the new identify is always preceded by a reset().
    func testSecondAccountNotAliased() async throws {
        let lateSource = FakeAuthSource()
        let (manager, client) = makeManager(resolver: FakeResolver("uid-A"), lateSource: lateSource)
        await manager.handleColdStart()        // identify A
        manager.handleLogout()                 // capture signed_out + reset
        client.identify("uid-B", properties: [:])  // fresh identify after reset

        let idxA = try XCTUnwrap(client.events.firstIndex(of: .identify("uid-A")))
        let idxReset = try XCTUnwrap(client.events.firstIndex(of: .reset))
        let idxB = try XCTUnwrap(client.events.lastIndex(of: .identify("uid-B")))
        XCTAssertTrue(idxA < idxReset && idxReset < idxB,
                      "reset must separate the two accounts so B is not aliased to A")
    }
}
