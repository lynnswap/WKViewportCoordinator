import Darwin
import XCTest
import notify

final class MiniBrowserUITests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    @available(iOS 26.0, *)
    func testViewportCoordinatorMaintainsViewportAcrossScenarioAndLifecycleChanges() throws {
        let commandSessionID = UUID().uuidString
        let app = launchApp(commandSessionID: commandSessionID)
        try waitForCommandReceiverReady(in: app, sessionID: commandSessionID)

        let initialNative = try nativeMetrics(in: app)
        let initialPage = try pageMetrics(in: app)
        XCTAssertEqual(initialNative.scenario, "standard")
        XCTAssertEqual(initialNative.chromeMode, HarnessCommand.ChromeMode.navigationBarHidden.rawValue)
        XCTAssertTrue(initialNative.attached)
        XCTAssertTrue(initialNative.windowAttached)
        XCTAssertEqual(initialNative.obscuredTop, initialNative.expectedTop)
        XCTAssertGreaterThan(initialNative.effectiveTop, 0)
        XCTAssertGreaterThan(initialNative.effectiveBottom, 0)
        XCTAssertGreaterThanOrEqual(initialPage.topMarkerTop, 0)

        postCommand(.setChromeMode(.navigationBarVisible), sessionID: commandSessionID)
        let chromeVisibleNative = try nativeMetrics(
            in: app,
            matching: {
                $0.chromeMode == HarnessCommand.ChromeMode.navigationBarVisible.rawValue
                    && $0.revision > initialNative.revision
            }
        )
        let chromeVisiblePage = try pageMetrics(in: app, matching: { $0.revision > initialPage.revision })
        XCTAssertEqual(chromeVisibleNative.obscuredTop, chromeVisibleNative.expectedTop)
        XCTAssertGreaterThan(chromeVisibleNative.expectedTop, initialNative.expectedTop)
        XCTAssertGreaterThan(chromeVisiblePage.revision, initialPage.revision)

        postCommand(.setChromeMode(.navigationBarHidden), sessionID: commandSessionID)
        let chromeHiddenNative = try nativeMetrics(
            in: app,
            matching: {
                $0.chromeMode == HarnessCommand.ChromeMode.navigationBarHidden.rawValue
                    && $0.revision > chromeVisibleNative.revision
            }
        )
        let chromeHiddenPage = try pageMetrics(in: app, matching: { $0.revision > chromeVisiblePage.revision })
        XCTAssertEqual(chromeHiddenNative.obscuredTop, chromeHiddenNative.expectedTop)
        XCTAssertLessThan(chromeHiddenNative.expectedTop, chromeVisibleNative.expectedTop)
        XCTAssertGreaterThan(chromeHiddenPage.revision, chromeVisiblePage.revision)

        postCommand(.setAttachment(.detached), sessionID: commandSessionID)
        let detached = try nextNativeMetrics(after: chromeHiddenNative.revision, in: app)
        XCTAssertFalse(detached.attached)
        XCTAssertFalse(detached.windowAttached)
        XCTAssertEqual(detached.expectedTop, 0)
        XCTAssertEqual(detached.expectedBottom, 0)

        postCommand(.setAttachment(.attached), sessionID: commandSessionID)
        let reattached = try nextNativeMetrics(after: detached.revision, in: app)
        XCTAssertTrue(reattached.attached)
        XCTAssertTrue(reattached.windowAttached)
        XCTAssertEqual(reattached.obscuredTop, reattached.expectedTop)
        XCTAssertGreaterThan(reattached.effectiveTop, 0)
        XCTAssertGreaterThan(reattached.effectiveBottom, 0)

        postCommand(.setScenario(.neverAdjustment), sessionID: commandSessionID)
        let neverNative = try nativeMetrics(
            in: app,
            matching: { $0.scenario == "neverAdjustment" && $0.revision > reattached.revision }
        )
        let neverPage = try pageMetrics(in: app, matching: { $0.revision > chromeHiddenPage.revision })
        XCTAssertEqual(neverNative.effectiveTop, neverNative.obscuredTop)
        XCTAssertEqual(neverNative.effectiveBottom, neverNative.obscuredBottom)
        XCTAssertLessThanOrEqual(neverNative.adjustedTop, neverNative.effectiveTop)
        XCTAssertLessThanOrEqual(neverNative.adjustedBottom, neverNative.effectiveBottom)

        postCommand(.setScenario(.standard), sessionID: commandSessionID)
        let standardBeforeExcludedNative = try nativeMetrics(
            in: app,
            matching: { $0.scenario == "standard" && $0.revision > neverNative.revision }
        )

        postCommand(.setChromeMode(.navigationBarVisible), sessionID: commandSessionID)
        let visibleStandardBeforeExcludedNative = try nativeMetrics(
            in: app,
            matching: {
                $0.chromeMode == HarnessCommand.ChromeMode.navigationBarVisible.rawValue
                    && $0.scenario == "standard"
                    && $0.revision > standardBeforeExcludedNative.revision
            }
        )
        let visibleStandardBeforeExcludedPage = try pageMetrics(in: app, matching: { $0.revision > neverPage.revision })

        postCommand(.setScenario(.excludeTopSafeArea), sessionID: commandSessionID)
        let excludedNative = try nativeMetrics(
            in: app,
            matching: { $0.scenario == "excludeTopSafeArea" && $0.revision > visibleStandardBeforeExcludedNative.revision }
        )
        let excludedPage = try pageMetrics(in: app, matching: { $0.revision > visibleStandardBeforeExcludedPage.revision })
        XCTAssertEqual(excludedNative.scenario, "excludeTopSafeArea")
        XCTAssertGreaterThan(excludedPage.revision, visibleStandardBeforeExcludedPage.revision)

        postCommand(.setScenario(.standard), sessionID: commandSessionID)
        let restoredStandard = try nativeMetrics(
            in: app,
            matching: { $0.scenario == "standard" && $0.revision > excludedNative.revision }
        )
        XCTAssertTrue(restoredStandard.attached)
        XCTAssertEqual(restoredStandard.obscuredTop, restoredStandard.expectedTop)

        postCommand(.focusBottomInput, sessionID: commandSessionID)
        let focusedPage = try pageMetrics(
            in: app,
            matching: { $0.activeElement == "bottom-input" && $0.revision > excludedPage.revision }
        )
        let focusedNative = try nativeMetrics(in: app, matching: { $0.revision > restoredStandard.revision })
        XCTAssertEqual(focusedPage.activeElement, "bottom-input")
        XCTAssertLessThanOrEqual(focusedPage.bottomInputBottom, focusedPage.viewportHeight)
        XCTAssertGreaterThanOrEqual(focusedNative.effectiveBottom, reattached.effectiveBottom)
    }

    @MainActor
    func testLegacyKeyboardFocusDoesNotDoubleCountBottomInset() throws {
        if #available(iOS 26.0, *) {
            throw XCTSkip("Legacy fallback path only")
        }

        let commandSessionID = UUID().uuidString
        let app = launchApp(commandSessionID: commandSessionID)
        try waitForCommandReceiverReady(in: app, sessionID: commandSessionID)

        let initialNative = try nativeMetrics(in: app)
        postCommand(.focusBottomInput, sessionID: commandSessionID)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let focusedNative = try nativeMetrics(in: app, matching: { $0.revision > initialNative.revision })
        let keyboardHeight = Int(app.keyboards.firstMatch.frame.height.rounded())
        let bottomInsetDelta = focusedNative.adjustedBottom - initialNative.adjustedBottom

        XCTAssertGreaterThan(keyboardHeight, 0)
        XCTAssertLessThan(
            bottomInsetDelta,
            Int((Double(keyboardHeight) * 1.6).rounded()),
            "legacy path should not add roughly two keyboard heights: keyboard=\(keyboardHeight), delta=\(bottomInsetDelta)"
        )
    }

    @MainActor
    func testKeyboardFocusKeepsFixedBottomMarkerWithinVisualViewport() throws {
        let commandSessionID = UUID().uuidString
        let app = launchApp(commandSessionID: commandSessionID)
        try waitForCommandReceiverReady(in: app, sessionID: commandSessionID)

        let initialPage = try pageMetrics(in: app)
        postCommand(.focusBottomInput, sessionID: commandSessionID)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        let focusedPage = try pageMetrics(in: app, matching: { page in
            page.activeElement == "bottom-input" && page.revision > initialPage.revision
        })

        XCTAssertLessThanOrEqual(
            focusedPage.fixedBottomBottom,
            focusedPage.viewportHeight,
            "fixed bottom marker should stay within the visual viewport after keyboard presentation: bottom=\(focusedPage.fixedBottomBottom), viewport=\(focusedPage.viewportHeight)"
        )
        XCTAssertTrue(focusedPage.fixedBottomWithinViewport)
    }

    @MainActor
    func testFixedBottomMarkerStaysWithinVisualViewportAcrossLegacyAndModernPaths() throws {
        let commandSessionID = UUID().uuidString
        let app = launchApp(commandSessionID: commandSessionID)
        try waitForCommandReceiverReady(in: app, sessionID: commandSessionID)

        let initialPage = try pageMetrics(in: app)
        XCTAssertLessThanOrEqual(
            initialPage.fixedBottomBottom,
            initialPage.viewportHeight,
            "fixed bottom marker should stay within the visual viewport: bottom=\(initialPage.fixedBottomBottom), viewport=\(initialPage.viewportHeight)"
        )
        XCTAssertTrue(initialPage.fixedBottomWithinViewport)

        postCommand(.setChromeMode(.navigationBarVisible), sessionID: commandSessionID)
        let navigationBarVisiblePage = try pageMetrics(in: app, matching: { page in
            page.status == "ready" && page.revision > initialPage.revision
        })

        XCTAssertLessThanOrEqual(
            navigationBarVisiblePage.fixedBottomBottom,
            navigationBarVisiblePage.viewportHeight,
            "fixed bottom marker should remain visible after chrome updates: bottom=\(navigationBarVisiblePage.fixedBottomBottom), viewport=\(navigationBarVisiblePage.viewportHeight)"
        )
        XCTAssertTrue(navigationBarVisiblePage.fixedBottomWithinViewport)
    }
}

@MainActor
private extension MiniBrowserUITests {
    enum HarnessCommand {
        private static let allowedSessionCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-_")
        )

        enum Scenario: String {
            case standard
            case neverAdjustment
            case excludeTopSafeArea
        }

        enum ChromeMode: String {
            case navigationBarVisible
            case navigationBarHidden
        }

        enum Attachment: String {
            case attached
            case detached
        }

        case setScenario(Scenario)
        case setChromeMode(ChromeMode)
        case setAttachment(Attachment)
        case reloadFixture
        case focusBottomInput

        func notificationName(for sessionID: String) -> String {
            let prefix = "wkviewport.minibrowser.command"
            let encodedSessionID = Self.encodeSessionID(sessionID)
            switch self {
            case .setScenario(let scenario):
                return "\(prefix).\(encodedSessionID).setScenario.\(scenario.rawValue)"
            case .setChromeMode(let chromeMode):
                return "\(prefix).\(encodedSessionID).setChromeMode.\(chromeMode.rawValue)"
            case .setAttachment(let attachment):
                return "\(prefix).\(encodedSessionID).setAttachment.\(attachment.rawValue)"
            case .reloadFixture:
                return "\(prefix).\(encodedSessionID).reloadFixture"
            case .focusBottomInput:
                return "\(prefix).\(encodedSessionID).focusBottomInput"
            }
        }

        private static func encodeSessionID(_ sessionID: String) -> String {
            sessionID.addingPercentEncoding(withAllowedCharacters: allowedSessionCharacters) ?? sessionID
        }
    }

    struct NativeMetrics: Decodable {
        let status: String
        let revision: Int
        let scenario: String
        let chromeMode: String
        let attached: Bool
        let windowAttached: Bool
        let obscuredTop: Int
        let obscuredBottom: Int
        let effectiveTop: Int
        let effectiveBottom: Int
        let adjustedTop: Int
        let adjustedBottom: Int
        let contentInsetTop: Int
        let contentInsetBottom: Int
        let expectedTop: Int
        let expectedBottom: Int
    }

    struct PageMetrics: Decodable {
        let status: String
        let revision: Int
        let activeElement: String
        let topMarkerTop: Int
        let bottomInputBottom: Int
        let fixedBottomBottom: Int
        let viewportHeight: Int
        let fixedBottomWithinViewport: Bool
    }

    func launchApp(commandSessionID: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MINIBROWSER_COMMAND_SESSION"] = commandSessionID
        app.launch()
        return app
    }

    func waitForCommandReceiverReady(in app: XCUIApplication, sessionID: String) throws {
        let deadline = Date().addingTimeInterval(10)

        while Date() < deadline {
            if probeValue(identifier: "harness.command.ready", in: app) == sessionID {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Timed out waiting for command receiver readiness")
        throw NSError(domain: "MiniBrowserUITests", code: 2, userInfo: nil)
    }

    func postCommand(_ command: HarnessCommand, sessionID: String) {
        let notificationName = command.notificationName(for: sessionID)
        let status = notify_post(notificationName)
        XCTAssertEqual(status, UInt32(NOTIFY_STATUS_OK), "Failed to post command: \(notificationName)")
    }

    func nativeMetrics(
        in app: XCUIApplication,
        matching predicate: @escaping (NativeMetrics) -> Bool = { $0.status == "ready" }
    ) throws -> NativeMetrics {
        try decodeMetrics(identifier: "harness.metrics.native", in: app, as: NativeMetrics.self, predicate: predicate)
    }

    func nextNativeMetrics(after revision: Int, in app: XCUIApplication) throws -> NativeMetrics {
        try nativeMetrics(in: app, matching: { $0.status == "ready" && $0.revision > revision })
    }

    func pageMetrics(
        in app: XCUIApplication,
        matching predicate: @escaping (PageMetrics) -> Bool = { $0.status == "ready" }
    ) throws -> PageMetrics {
        try decodeMetrics(identifier: "harness.metrics.page", in: app, as: PageMetrics.self, predicate: predicate)
    }

    func decodeMetrics<T: Decodable>(
        identifier: String,
        in app: XCUIApplication,
        as type: T.Type,
        predicate: @escaping (T) -> Bool
    ) throws -> T {
        let deadline = Date().addingTimeInterval(10)
        let decoder = JSONDecoder()

        while Date() < deadline {
            if let rawValue = probeValue(identifier: identifier, in: app),
               let data = rawValue.data(using: .utf8),
               let decoded = try? decoder.decode(T.self, from: data),
               predicate(decoded) {
                return decoded
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Timed out waiting for metrics from \(identifier)")
        throw NSError(domain: "MiniBrowserUITests", code: 1, userInfo: nil)
    }

    func probeValue(identifier: String, in app: XCUIApplication) -> String? {
        for element in [
            app.otherElements[identifier],
            app.staticTexts[identifier]
        ] where element.exists {
            if let rawValue = element.value as? String {
                return rawValue
            }
        }

        return nil
    }
}
