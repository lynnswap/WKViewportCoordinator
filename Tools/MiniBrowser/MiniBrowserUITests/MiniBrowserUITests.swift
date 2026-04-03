import XCTest

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
        let app = launchApp()

        let initialNative = try nativeMetrics(in: app)
        let initialPage = try pageMetrics(in: app)
        XCTAssertEqual(initialNative.scenario, "standard")
        XCTAssertTrue(initialNative.attached)
        XCTAssertTrue(initialNative.windowAttached)
        XCTAssertEqual(initialNative.obscuredTop, initialNative.expectedTop)
        XCTAssertEqual(initialNative.obscuredBottom, initialNative.expectedBottom)
        XCTAssertGreaterThan(initialNative.effectiveTop, 0)
        XCTAssertGreaterThan(initialNative.effectiveBottom, 0)
        XCTAssertGreaterThanOrEqual(initialPage.topMarkerTop, 0)

        tapButton("harness.action.toggleAttachment", fallbackTitles: ["Detach", "Attach"], in: app)
        let detached = try nextNativeMetrics(after: initialNative.revision, in: app)
        XCTAssertFalse(detached.attached)
        XCTAssertFalse(detached.windowAttached)
        XCTAssertEqual(detached.expectedTop, 0)
        XCTAssertEqual(detached.expectedBottom, 0)

        tapButton("harness.action.toggleAttachment", fallbackTitles: ["Detach", "Attach"], in: app)
        let reattached = try nextNativeMetrics(after: detached.revision, in: app)
        XCTAssertTrue(reattached.attached)
        XCTAssertTrue(reattached.windowAttached)
        XCTAssertEqual(reattached.obscuredTop, reattached.expectedTop)
        XCTAssertEqual(reattached.obscuredBottom, reattached.expectedBottom)
        XCTAssertGreaterThan(reattached.effectiveTop, 0)
        XCTAssertGreaterThan(reattached.effectiveBottom, 0)

        selectScenario("Never Adjustment", expectedRawValue: "neverAdjustment", in: app)
        let neverNative = try nativeMetrics(
            in: app,
            matching: { $0.scenario == "neverAdjustment" && $0.revision > reattached.revision }
        )
        XCTAssertEqual(neverNative.effectiveTop, neverNative.obscuredTop)
        XCTAssertEqual(neverNative.effectiveBottom, neverNative.obscuredBottom)
        XCTAssertLessThanOrEqual(neverNative.adjustedTop, neverNative.effectiveTop)
        XCTAssertLessThanOrEqual(neverNative.adjustedBottom, neverNative.effectiveBottom)

        selectScenario("Exclude Top Safe Area", expectedRawValue: "excludeTopSafeArea", in: app)
        let excludedPage = try pageMetrics(in: app, matching: { $0.revision > initialPage.revision })
        XCTAssertLessThan(excludedPage.topMarkerTop, initialPage.topMarkerTop)

        selectScenario("Standard", expectedRawValue: "standard", in: app)
        let restoredStandard = try nativeMetrics(
            in: app,
            matching: { $0.scenario == "standard" && $0.revision > neverNative.revision }
        )
        XCTAssertTrue(restoredStandard.attached)
        XCTAssertEqual(restoredStandard.obscuredTop, restoredStandard.expectedTop)
        XCTAssertEqual(restoredStandard.obscuredBottom, restoredStandard.expectedBottom)

        tapButton("harness.action.focusBottomInput", fallbackTitles: ["Focus"], in: app)
        let focusedPage = try pageMetrics(
            in: app,
            matching: { $0.activeElement == "bottom-input" && $0.revision > excludedPage.revision }
        )
        let focusedNative = try nativeMetrics(in: app, matching: { $0.revision > restoredStandard.revision })
        XCTAssertEqual(focusedPage.activeElement, "bottom-input")
        XCTAssertLessThanOrEqual(focusedPage.bottomInputBottom, focusedPage.viewportHeight)
        XCTAssertGreaterThanOrEqual(focusedNative.effectiveBottom, reattached.effectiveBottom)
    }
}

private extension MiniBrowserUITests {
    struct NativeMetrics: Decodable {
        let status: String
        let revision: Int
        let scenario: String
        let attached: Bool
        let windowAttached: Bool
        let obscuredTop: Int
        let obscuredBottom: Int
        let effectiveTop: Int
        let effectiveBottom: Int
        let adjustedTop: Int
        let adjustedBottom: Int
        let expectedTop: Int
        let expectedBottom: Int
    }

    struct PageMetrics: Decodable {
        let status: String
        let revision: Int
        let activeElement: String
        let topMarkerTop: Int
        let bottomInputBottom: Int
        let viewportHeight: Int
    }

    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func tapButton(_ identifier: String, fallbackTitles: [String] = [], in app: XCUIApplication) {
        let candidates = [app.buttons[identifier]] + fallbackTitles.map { app.buttons[$0] }

        for button in candidates where button.waitForExistence(timeout: 2) {
            button.tap()
            return
        }

        XCTFail("Missing button: \(identifier)")
    }

    func selectScenario(_ title: String, expectedRawValue: String, in app: XCUIApplication) {
        tapButton("harness.action.scenarioMenu", in: app)

        let predicate = NSPredicate(format: "label == %@", title)
        let deadline = Date().addingTimeInterval(3)

        while Date() < deadline {
            let elements = app.descendants(matching: .any).matching(predicate).allElementsBoundByIndex
            if let element = elements.first(where: \.isHittable) {
                element.tap()
                XCTAssertEqual(
                    (try? nativeMetrics(in: app, matching: { $0.scenario == expectedRawValue }))?.scenario,
                    expectedRawValue
                )
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("Missing scenario action: \(title)")
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
        let element = probeElement(identifier: identifier, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing accessibility probe: \(identifier)")

        let deadline = Date().addingTimeInterval(10)
        let decoder = JSONDecoder()

        while Date() < deadline {
            if let rawValue = element.value as? String,
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

    func probeElement(identifier: String, in app: XCUIApplication) -> XCUIElement {
        let candidates = [
            app.otherElements[identifier],
            app.staticTexts[identifier]
        ]

        for element in candidates where element.exists {
            return element
        }

        return candidates[0]
    }
}
