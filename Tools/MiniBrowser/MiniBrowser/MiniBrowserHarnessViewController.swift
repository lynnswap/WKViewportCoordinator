import Darwin
import Foundation
import ObjectiveC
import Observation
import SwiftUI
import UIKit
import WebKit
import WKViewportCoordinator

@MainActor
struct MiniBrowserHarnessContainer: UIViewControllerRepresentable {
    let state: MiniBrowserHarnessState

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: MiniBrowserHarnessViewController(state: state))
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        _ = uiViewController
        _ = context
    }
}

@MainActor
@Observable
final class MiniBrowserHarnessState {
    nonisolated enum SelfTestMode: String, Sendable {
        case viewport
    }

    nonisolated enum ChromeMode: String, CaseIterable, Codable, Sendable {
        case navigationBarVisible
        case navigationBarHidden

        var displayName: String {
            switch self {
            case .navigationBarVisible:
                "Navigation Bar"
            case .navigationBarHidden:
                "No Navigation Bar"
            }
        }

        var isNavigationBarHidden: Bool {
            self == .navigationBarHidden
        }
    }

    nonisolated enum Scenario: String, CaseIterable, Codable, Sendable {
        case standard
        case neverAdjustment
        case excludeTopSafeArea

        var displayName: String {
            switch self {
            case .standard:
                "Standard"
            case .neverAdjustment:
                "Never Adjustment"
            case .excludeTopSafeArea:
                "Exclude Top Safe Area"
            }
        }

    }

    struct NativeMetrics: Codable, Equatable {
        var status: String
        var revision: Int
        var scenario: String
        var chromeMode: String
        var attached: Bool
        var windowAttached: Bool
        var obscuredTop: Int
        var obscuredBottom: Int
        var effectiveTop: Int
        var effectiveBottom: Int
        var adjustedTop: Int
        var adjustedBottom: Int
        var contentInsetTop: Int
        var contentInsetBottom: Int
        var projectedTop: Int
        var projectedBottom: Int
        var publicObscuredTop: Int?
        var publicObscuredBottom: Int?
        var privateObscuredTop: Int?
        var privateObscuredBottom: Int?
        var computedObscuredTop: Int?
        var computedObscuredBottom: Int?
        var computedUnobscuredSafeAreaTop: Int?
        var computedUnobscuredSafeAreaBottom: Int?
        var scrollViewSystemContentInsetTop: Int?
        var scrollViewSystemContentInsetBottom: Int?
        var scrollViewPrivateSystemContentInsetTop: Int?
        var scrollViewPrivateSystemContentInsetBottom: Int?
        var webViewSafeAreaTop: Int
        var webViewSafeAreaBottom: Int
        var minimumViewportInsetTop: Int
        var minimumViewportInsetBottom: Int
        var maximumViewportInsetTop: Int
        var maximumViewportInsetBottom: Int
        var hasSetObscuredInsets: Bool?
        var hasSetUnobscuredSafeAreaInsets: Bool?
        var errorMessage: String?

        static func idle(for scenario: Scenario, chromeMode: ChromeMode) -> Self {
            Self(
                status: "idle",
                revision: 0,
                scenario: scenario.rawValue,
                chromeMode: chromeMode.rawValue,
                attached: false,
                windowAttached: false,
                obscuredTop: 0,
                obscuredBottom: 0,
                effectiveTop: 0,
                effectiveBottom: 0,
                adjustedTop: 0,
                adjustedBottom: 0,
                contentInsetTop: 0,
                contentInsetBottom: 0,
                projectedTop: 0,
                projectedBottom: 0,
                publicObscuredTop: nil,
                publicObscuredBottom: nil,
                privateObscuredTop: nil,
                privateObscuredBottom: nil,
                computedObscuredTop: nil,
                computedObscuredBottom: nil,
                computedUnobscuredSafeAreaTop: nil,
                computedUnobscuredSafeAreaBottom: nil,
                scrollViewSystemContentInsetTop: nil,
                scrollViewSystemContentInsetBottom: nil,
                scrollViewPrivateSystemContentInsetTop: nil,
                scrollViewPrivateSystemContentInsetBottom: nil,
                webViewSafeAreaTop: 0,
                webViewSafeAreaBottom: 0,
                minimumViewportInsetTop: 0,
                minimumViewportInsetBottom: 0,
                maximumViewportInsetTop: 0,
                maximumViewportInsetBottom: 0,
                hasSetObscuredInsets: nil,
                hasSetUnobscuredSafeAreaInsets: nil,
                errorMessage: nil
            )
        }
    }

    struct PageMetrics: Codable, Equatable {
        var status: String
        var revision: Int
        var activeElement: String
        var topMarkerTop: Int
        var topMarkerBottom: Int
        var bottomInputTop: Int
        var bottomInputBottom: Int
        var fixedBottomTop: Int
        var fixedBottomBottom: Int
        var viewportHeight: Int
        var bottomWithinViewport: Bool
        var fixedBottomWithinViewport: Bool
        var errorMessage: String?

        static let idle = Self(
            status: "idle",
            revision: 0,
            activeElement: "",
            topMarkerTop: -1,
            topMarkerBottom: -1,
            bottomInputTop: -1,
            bottomInputBottom: -1,
            fixedBottomTop: -1,
            fixedBottomBottom: -1,
            viewportHeight: -1,
            bottomWithinViewport: false,
            fixedBottomWithinViewport: false,
            errorMessage: nil
        )
    }

    private struct FocusResult: Decodable {
        var status: String
    }

    let webView: ManagedViewportWebView
    let selfTestMode: SelfTestMode?
    private let selfTestInputDelegate: MiniBrowserSelfTestInputDelegate?
    private let selfTestInputDelegateInstalled: Bool
    private(set) var scenario: Scenario
    private(set) var chromeMode: ChromeMode
    private(set) var isAttached = true
    private(set) var fixtureLoaded = false
    private(set) var nativeMetrics: NativeMetrics
    private(set) var pageMetrics = PageMetrics.idle

    init(processInfo: ProcessInfo = .processInfo) {
        let initialScenario = Scenario(rawValue: processInfo.environment["MINIBROWSER_SCENARIO"] ?? "") ?? .standard
        let initialChromeMode = ChromeMode(rawValue: processInfo.environment["MINIBROWSER_CHROME_MODE"] ?? "") ?? .navigationBarHidden
        let selfTestMode = SelfTestMode(rawValue: processInfo.environment["MINIBROWSER_SELF_TEST"] ?? "")
        let selfTestInputDelegate = selfTestMode == .viewport ? MiniBrowserSelfTestInputDelegate() : nil
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = ManagedViewportWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
        let selfTestInputDelegateInstalled = selfTestInputDelegate.map {
            Self.installSelfTestInputDelegate($0, on: webView)
        } ?? false

        self.webView = webView
        self.selfTestMode = selfTestMode
        self.selfTestInputDelegate = selfTestInputDelegate
        self.selfTestInputDelegateInstalled = selfTestInputDelegateInstalled
        scenario = initialScenario
        chromeMode = initialChromeMode
        nativeMetrics = NativeMetrics.idle(for: initialScenario, chromeMode: initialChromeMode)
        applyViewportBehavior(for: initialScenario)
    }

    private static func installSelfTestInputDelegate(_ inputDelegate: MiniBrowserSelfTestInputDelegate, on webView: WKWebView) -> Bool {
        let selector = NSSelectorFromString("_setInputDelegate:")
        guard webView.responds(to: selector) else {
            return false
        }

        typealias SetInputDelegate = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let implementation = webView.method(for: selector)
        let setInputDelegate = unsafeBitCast(implementation, to: SetInputDelegate.self)
        setInputDelegate(webView, selector, inputDelegate)
        return true
    }

    var shouldRequireSelfTestInputSessionStart: Bool {
        selfTestInputDelegateInstalled
    }

    var selfTestInputSessionStartCount: Int {
        selfTestInputDelegate?.inputSessionStartCount ?? 0
    }

    var nativeMetricsJSON: String {
        encode(nativeMetrics)
    }

    var pageMetricsJSON: String {
        encode(pageMetrics)
    }

    func loadFixtureIfNeeded() {
        guard fixtureLoaded == false else {
            return
        }
        reloadFixture()
    }

    func reloadFixture() {
        guard let fixtureURL else {
            pageMetrics = errorPageMetrics(message: "missing-fixture")
            return
        }

        fixtureLoaded = false
        pageMetrics = PageMetrics(
            status: "loading",
            revision: pageMetrics.revision + 1,
            activeElement: "",
            topMarkerTop: -1,
            topMarkerBottom: -1,
            bottomInputTop: -1,
            bottomInputBottom: -1,
            fixedBottomTop: -1,
            fixedBottomBottom: -1,
            viewportHeight: -1,
            bottomWithinViewport: false,
            fixedBottomWithinViewport: false,
            errorMessage: nil
        )
        webView.loadFileURL(fixtureURL, allowingReadAccessTo: fixtureURL.deletingLastPathComponent())
    }

    func markFixtureLoaded() {
        fixtureLoaded = true
    }

    func applyScenario(_ scenario: Scenario) {
        self.scenario = scenario
        applyViewportBehavior(for: scenario)
        nativeMetrics.scenario = scenario.rawValue
    }

    func applyChromeMode(_ chromeMode: ChromeMode) {
        self.chromeMode = chromeMode
        nativeMetrics.chromeMode = chromeMode.rawValue
    }

    func setAttached(_ isAttached: Bool) {
        self.isAttached = isAttached
    }

    @discardableResult
    func captureNativeMetrics(in hostViewController: UIViewController) -> NativeMetrics {
        hostViewController.navigationController?.view.layoutIfNeeded()
        hostViewController.view.layoutIfNeeded()
        webView.superview?.layoutIfNeeded()
        webView.layoutIfNeeded()

        let attached = webView.superview != nil
        let windowAttached = webView.window != nil
        let obscuredInsets: UIEdgeInsets
        if #available(iOS 26.0, *) {
            obscuredInsets = webView.obscuredContentInsets
        } else {
            obscuredInsets = .zero
        }

        let adjustedInsets = webView.scrollView.adjustedContentInset
        let contentInsets = webView.scrollView.contentInset
        let projectedInsets = projectedChromeInsets(in: hostViewController, attached: attached && windowAttached)
        let runtimeDiagnostics = MiniBrowserViewportRuntimeDiagnosticsReader.capture(for: webView)

        let metrics = NativeMetrics(
            status: "ready",
            revision: nativeMetrics.revision + 1,
            scenario: scenario.rawValue,
            chromeMode: chromeMode.rawValue,
            attached: attached,
            windowAttached: windowAttached,
            obscuredTop: Self.rounded(obscuredInsets.top),
            obscuredBottom: Self.rounded(obscuredInsets.bottom),
            effectiveTop: max(Self.rounded(obscuredInsets.top), Self.rounded(adjustedInsets.top), Self.rounded(contentInsets.top)),
            effectiveBottom: max(Self.rounded(obscuredInsets.bottom), Self.rounded(adjustedInsets.bottom), Self.rounded(contentInsets.bottom)),
            adjustedTop: Self.rounded(adjustedInsets.top),
            adjustedBottom: Self.rounded(adjustedInsets.bottom),
            contentInsetTop: Self.rounded(contentInsets.top),
            contentInsetBottom: Self.rounded(contentInsets.bottom),
            projectedTop: projectedInsets.top,
            projectedBottom: projectedInsets.bottom,
            publicObscuredTop: Self.rounded(runtimeDiagnostics.publicObscuredContentInsets?.top),
            publicObscuredBottom: Self.rounded(runtimeDiagnostics.publicObscuredContentInsets?.bottom),
            privateObscuredTop: Self.rounded(runtimeDiagnostics.privateObscuredInsets?.top),
            privateObscuredBottom: Self.rounded(runtimeDiagnostics.privateObscuredInsets?.bottom),
            computedObscuredTop: Self.rounded(runtimeDiagnostics.computedObscuredInset?.top),
            computedObscuredBottom: Self.rounded(runtimeDiagnostics.computedObscuredInset?.bottom),
            computedUnobscuredSafeAreaTop: Self.rounded(runtimeDiagnostics.computedUnobscuredSafeAreaInset?.top),
            computedUnobscuredSafeAreaBottom: Self.rounded(runtimeDiagnostics.computedUnobscuredSafeAreaInset?.bottom),
            scrollViewSystemContentInsetTop: Self.rounded(runtimeDiagnostics.scrollViewSystemContentInset?.top),
            scrollViewSystemContentInsetBottom: Self.rounded(runtimeDiagnostics.scrollViewSystemContentInset?.bottom),
            scrollViewPrivateSystemContentInsetTop: Self.rounded(runtimeDiagnostics.scrollViewPrivateSystemContentInset?.top),
            scrollViewPrivateSystemContentInsetBottom: Self.rounded(runtimeDiagnostics.scrollViewPrivateSystemContentInset?.bottom),
            webViewSafeAreaTop: Self.rounded(runtimeDiagnostics.webViewSafeAreaInsets.top),
            webViewSafeAreaBottom: Self.rounded(runtimeDiagnostics.webViewSafeAreaInsets.bottom),
            minimumViewportInsetTop: Self.rounded(runtimeDiagnostics.minimumViewportInset.top),
            minimumViewportInsetBottom: Self.rounded(runtimeDiagnostics.minimumViewportInset.bottom),
            maximumViewportInsetTop: Self.rounded(runtimeDiagnostics.maximumViewportInset.top),
            maximumViewportInsetBottom: Self.rounded(runtimeDiagnostics.maximumViewportInset.bottom),
            hasSetObscuredInsets: runtimeDiagnostics.haveSetObscuredInsets,
            hasSetUnobscuredSafeAreaInsets: runtimeDiagnostics.haveSetUnobscuredSafeAreaInsets,
            errorMessage: nil
        )
        nativeMetrics = metrics
        return metrics
    }

    func capturePageMetrics() async {
        do {
            try await refreshPageMetrics()
        } catch {
            handlePageMetricsFailure(error)
        }
    }

    @discardableResult
    func refreshPageMetrics() async throws -> PageMetrics {
        guard fixtureLoaded else {
            setPageMetricsLoading()
            throw PageMetricsError.fixtureNotLoaded
        }

        // JavaScript frame callbacks can run before native viewport changes reach WebContent.
        // Snapshot completion includes pending screen updates before we read DOM geometry.
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = true
        configuration.snapshotWidth = 1
        _ = try await webView.takeSnapshot(configuration: configuration)
        let rawJSON = try await callAsyncJavaScriptString("return window.testHarness.captureState();")
        let metrics = try decodePageMetrics(from: rawJSON)
        pageMetrics = metrics
        return metrics
    }

    func focusBottomInput() async {
        do {
            try await focusBottomInputForSelfTest()
            try await scrollBottomInputIntoViewAndRefreshPageMetrics()
        } catch {
            handlePageMetricsFailure(error)
        }
    }

    @discardableResult
    func focusBottomInputForSelfTest() async throws -> PageMetrics {
        guard fixtureLoaded else {
            setPageMetricsLoading()
            throw PageMetricsError.fixtureNotLoaded
        }

        // DOM focus alone can succeed without starting a keyboard input session.
        guard webView.becomeFirstResponder() else {
            throw PageMetricsError.focusFailed("web view could not become first responder")
        }

        let rawJSON = try await callAsyncJavaScriptString(
            "return window.testHarness.focusInput('bottom-input');"
        )
        let result = try JSONDecoder().decode(FocusResult.self, from: Data(rawJSON.utf8))
        guard result.status == "ready" else {
            throw PageMetricsError.focusFailed("focus failed")
        }
        return pageMetrics
    }

    @discardableResult
    func scrollBottomInputIntoViewAndRefreshPageMetrics() async throws -> PageMetrics {
        guard fixtureLoaded else {
            setPageMetricsLoading()
            throw PageMetricsError.fixtureNotLoaded
        }

        _ = try await callAsyncJavaScriptString(
            "return window.testHarness.scrollInputIntoView('bottom-input');"
        )
        return try await refreshPageMetrics()
    }

    func markPageMetricsError(_ message: String) {
        pageMetrics = errorPageMetrics(message: message)
    }

    private func decodePageMetrics(from rawJSON: String) throws -> PageMetrics {
        var metrics = try JSONDecoder().decode(PageMetrics.self, from: Data(rawJSON.utf8))
        metrics.revision = pageMetrics.revision + 1
        if metrics.status != "error" {
            metrics.status = "ready"
            metrics.errorMessage = nil
        }
        return metrics
    }

    private func callAsyncJavaScriptString(_ script: String) async throws -> String {
        let result = try await webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
        guard let string = result as? String else {
            throw PageMetricsError.unexpectedResultType
        }
        return string
    }

    private func errorPageMetrics(message: String) -> PageMetrics {
        PageMetrics(
            status: "error",
            revision: pageMetrics.revision + 1,
            activeElement: "",
            topMarkerTop: -1,
            topMarkerBottom: -1,
            bottomInputTop: -1,
            bottomInputBottom: -1,
            fixedBottomTop: -1,
            fixedBottomBottom: -1,
            viewportHeight: -1,
            bottomWithinViewport: false,
            fixedBottomWithinViewport: false,
            errorMessage: message
        )
    }

    private func setPageMetricsLoading() {
        pageMetrics = PageMetrics(
            status: "loading",
            revision: pageMetrics.revision + 1,
            activeElement: "",
            topMarkerTop: -1,
            topMarkerBottom: -1,
            bottomInputTop: -1,
            bottomInputBottom: -1,
            fixedBottomTop: -1,
            fixedBottomBottom: -1,
            viewportHeight: -1,
            bottomWithinViewport: false,
            fixedBottomWithinViewport: false,
            errorMessage: nil
        )
    }

    private func handlePageMetricsFailure(_ error: any Error) {
        pageMetrics = errorPageMetrics(message: error.localizedDescription)
    }

    private var fixtureURL: URL? {
        Bundle.main.url(forResource: "ViewportFixture", withExtension: "html")
    }

    private func projectedChromeInsets(in hostViewController: UIViewController, attached: Bool) -> (top: Int, bottom: Int) {
        guard attached, hostViewController.viewIfLoaded != nil else {
            return (0, 0)
        }
        let hostView = webView.superview ?? hostViewController.viewIfLoaded
        let safeAreaInsets = projectedWindowSafeAreaInsets(in: hostView)
        let topObscuredHeight = max(
            safeAreaInsets.top,
            topEdgeObscuredHeight(
                of: hostViewController.navigationController?.navigationBar,
                in: hostView,
                extendingFrom: safeAreaInsets.top
            )
        )
        let bottomObscuredHeight = bottomEdgeObscuredHeight(
            of: [
                hostViewController.tabBarController?.tabBar,
                resolvedVisibleToolbar(for: hostViewController),
            ],
            in: hostView,
            extendingFrom: safeAreaInsets.bottom
        )
        return (Self.rounded(topObscuredHeight), Self.rounded(bottomObscuredHeight))
    }

    private func applyViewportBehavior(for scenario: Scenario) {
        switch scenario {
        case .standard:
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            webView.viewportObscuredContentInsetEdgesAffectedBySafeArea = [.top, .bottom]
        case .neverAdjustment:
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.viewportObscuredContentInsetEdgesAffectedBySafeArea = [.top, .bottom]
        case .excludeTopSafeArea:
            webView.scrollView.contentInsetAdjustmentBehavior = .automatic
            webView.viewportObscuredContentInsetEdgesAffectedBySafeArea = [.bottom]
        }
    }

    private func projectedWindowSafeAreaInsets(in hostView: UIView?) -> UIEdgeInsets {
        guard let hostView, let window = hostView.window else {
            return .zero
        }

        let hostRectInWindow = hostView.convert(hostView.bounds, to: window)
        let safeRectInWindow = window.bounds.inset(by: window.safeAreaInsets)

        return UIEdgeInsets(
            top: max(0, safeRectInWindow.minY - hostRectInWindow.minY),
            left: max(0, safeRectInWindow.minX - hostRectInWindow.minX),
            bottom: max(0, hostRectInWindow.maxY - safeRectInWindow.maxY),
            right: max(0, hostRectInWindow.maxX - safeRectInWindow.maxX)
        )
    }

    private func resolvedVisibleToolbar(for hostViewController: UIViewController) -> UIToolbar? {
        guard let navigationController = hostViewController.navigationController else {
            return nil
        }
        guard navigationController.isToolbarHidden == false else {
            return nil
        }
        return navigationController.toolbar
    }

    private func topEdgeObscuredHeight(
        of chromeView: UIView?,
        in hostView: UIView?,
        extendingFrom leadingObscuredHeight: CGFloat = 0
    ) -> CGFloat {
        guard let chromeView, let hostView else {
            return 0
        }
        guard let window = hostView.window, chromeView.window != nil else {
            return 0
        }
        guard chromeView.isHidden == false, effectiveAlpha(of: chromeView) > 0 else {
            return 0
        }

        let hostFrameInWindow = hostView.convert(hostView.bounds, to: window)
        let chromeFrameInWindow = chromeView.convert(chromeView.bounds, to: window)
        let leadingObscuredMaxY = hostFrameInWindow.minY + max(0, leadingObscuredHeight)
        guard chromeFrameInWindow.minY <= leadingObscuredMaxY else {
            return 0
        }
        guard chromeFrameInWindow.maxY > hostFrameInWindow.minY else {
            return 0
        }

        return max(
            max(0, leadingObscuredHeight),
            max(0, min(hostFrameInWindow.maxY, chromeFrameInWindow.maxY) - hostFrameInWindow.minY)
        )
    }

    private func bottomEdgeObscuredHeight(
        of chromeViews: [UIView?],
        in hostView: UIView?,
        extendingFrom trailingObscuredHeight: CGFloat = 0
    ) -> CGFloat {
        guard let hostView else {
            return max(0, trailingObscuredHeight)
        }
        guard let window = hostView.window else {
            return max(0, trailingObscuredHeight)
        }

        let hostFrameInWindow = hostView.convert(hostView.bounds, to: window)
        let chromeFramesInWindow = chromeViews.compactMap { chromeView -> CGRect? in
            guard let chromeView, chromeView.window != nil else {
                return nil
            }
            guard chromeView.isHidden == false, effectiveAlpha(of: chromeView) > 0 else {
                return nil
            }
            return chromeView.convert(chromeView.bounds, to: window)
        }

        var obscuredMinY = hostFrameInWindow.maxY - max(0, trailingObscuredHeight)
        var didExtend = true

        while didExtend {
            didExtend = false

            for chromeFrameInWindow in chromeFramesInWindow {
                guard chromeFrameInWindow.minY < hostFrameInWindow.maxY else {
                    continue
                }
                guard chromeFrameInWindow.maxY > hostFrameInWindow.minY else {
                    continue
                }

                let overlapMinY = max(hostFrameInWindow.minY, chromeFrameInWindow.minY)
                let overlapMaxY = min(hostFrameInWindow.maxY, chromeFrameInWindow.maxY)
                guard overlapMaxY >= obscuredMinY else {
                    continue
                }
                guard overlapMinY < obscuredMinY else {
                    continue
                }

                obscuredMinY = overlapMinY
                didExtend = true
            }
        }

        return max(0, hostFrameInWindow.maxY - obscuredMinY)
    }

    private func effectiveAlpha(of view: UIView) -> CGFloat {
        var alpha = view.alpha
        var currentSuperview = view.superview

        while let superview = currentSuperview {
            if superview.isHidden {
                return 0
            }
            alpha *= superview.alpha
            currentSuperview = superview.superview
        }

        return alpha
    }

    private func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value), let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func rounded(_ value: CGFloat) -> Int {
        Int(value.rounded())
    }

    private static func rounded(_ value: CGFloat?) -> Int? {
        value.map { Int($0.rounded()) }
    }
}

private enum PageMetricsError: Error, LocalizedError, CustomStringConvertible {
    case unexpectedResultType
    case fixtureNotLoaded
    case focusFailed(String)

    var errorDescription: String? {
        description
    }

    var description: String {
        switch self {
        case .unexpectedResultType:
            "unexpected page metrics result type"
        case .fixtureNotLoaded:
            "fixture not loaded"
        case let .focusFailed(message):
            "focus failed: \(message)"
        }
    }
}

private final class MiniBrowserSelfTestInputDelegate: NSObject {
    private(set) var inputSessionStartCount = 0

    @objc(_webView:focusShouldStartInputSession:)
    func _webView(_ webView: WKWebView, focusShouldStartInputSession info: AnyObject) -> Bool {
        true
    }

    @objc(_webView:decidePolicyForFocusedElement:)
    func _webView(_ webView: WKWebView, decidePolicyForFocusedElement info: AnyObject) -> Int {
        1
    }

    @objc(_webView:didStartInputSession:)
    func _webView(_ webView: WKWebView, didStartInputSession inputSession: AnyObject) {
        inputSessionStartCount += 1
    }
}

@MainActor
final class MiniBrowserHarnessViewController: UIViewController {
    private let state: MiniBrowserHarnessState
    private let webViewContainerView = UIView()
    private var webViewConstraints: [NSLayoutConstraint] = []
    private var didStartSelfTest = false
    private var selfTestTask: Task<Void, Never>?
    private var selfTestWatchdog: DispatchSourceTimer?
    private var currentSelfTestChecks: [String] = []
    private var currentSelfTestSnapshots: [MiniBrowserSelfTestSnapshot] = []

    private lazy var actionsItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Actions", image: nil, primaryAction: nil, menu: actionsMenu())
        item.accessibilityIdentifier = "harness.action.actionsMenu"
        return item
    }()
    private lazy var chromeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Chrome", image: nil, primaryAction: nil, menu: chromeMenu())
        item.accessibilityIdentifier = "harness.action.chromeMenu"
        return item
    }()
    private lazy var scenarioItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Viewport", image: nil, primaryAction: nil, menu: scenarioMenu())
        item.accessibilityIdentifier = "harness.action.scenarioMenu"
        return item
    }()

    init(state: MiniBrowserHarnessState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
    }

    isolated deinit {
        selfTestTask?.cancel()
        selfTestWatchdog?.cancel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        configureChrome()
        state.webView.viewportHostViewController = self
        state.webView.navigationDelegate = self
        beginObservation()
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyChrome(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        state.loadFixtureIfNeeded()
        scheduleNativeCapture()
        startSelfTestIfReady()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        scheduleNativeCapture()
    }

    private func configureViewHierarchy() {
        view.backgroundColor = .systemBackground
        webViewContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webViewContainerView)

        NSLayoutConstraint.activate([
            webViewContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            webViewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webViewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureChrome() {
        syncChromeControls()
    }

    private func beginObservation() {
        withObservationTracking {
            _ = state.isAttached
            _ = state.scenario
            _ = state.chromeMode
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.beginObservation()
                self.render()
            }
        }
    }

    private func render() {
        if state.isAttached {
            attachWebViewIfNeeded()
        } else {
            detachWebViewIfNeeded()
        }

        applyChrome(animated: false)
        syncChromeControls()
    }

    private func attachWebViewIfNeeded() {
        guard state.webView.superview !== webViewContainerView else {
            return
        }

        NSLayoutConstraint.deactivate(webViewConstraints)
        webViewConstraints.removeAll()

        let webView = state.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViewContainerView.addSubview(webView)
        webViewConstraints = [
            webView.topAnchor.constraint(equalTo: webViewContainerView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: webViewContainerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webViewContainerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: webViewContainerView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(webViewConstraints)
        webView.viewportHostViewController = self
    }

    private func detachWebViewIfNeeded() {
        guard state.webView.superview != nil else {
            return
        }

        NSLayoutConstraint.deactivate(webViewConstraints)
        webViewConstraints.removeAll()
        state.webView.removeFromSuperview()
    }

    private func scenarioMenu() -> UIMenu {
        UIMenu(
            title: "Viewport",
            children: MiniBrowserHarnessState.Scenario.allCases.map { scenario in
                UIAction(
                    title: scenario.displayName,
                    state: scenario == state.scenario ? .on : .off
                ) { [weak self] _ in
                    self?.setScenario(scenario)
                }
            }
        )
    }

    private func syncChromeControls() {
        let scenarioMenu = scenarioMenu()
        let chromeMenu = chromeMenu()
        let actionsMenu = actionsMenu()

        scenarioItem.menu = scenarioMenu
        chromeItem.menu = chromeMenu
        actionsItem.menu = actionsMenu

        navigationItem.title = state.chromeMode.isNavigationBarHidden ? nil : "MiniBrowser"
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItems = nil
        setToolbarItems(
            [
                scenarioItem,
                .flexibleSpace(),
                chromeItem,
                .flexibleSpace(),
                actionsItem
            ],
            animated: false
        )
    }

    private func actionsMenu() -> UIMenu {
        UIMenu(
            title: "Actions",
            children: [
                UIAction(title: "Reload") { [weak self] _ in
                    self?.reloadFixture()
                },
                UIAction(title: state.isAttached ? "Detach WebView" : "Attach WebView") { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.setAttached(!self.state.isAttached)
                },
                UIAction(title: "Focus Bottom Input") { [weak self] _ in
                    self?.focusBottomInput()
                }
            ]
        )
    }

    private func chromeMenu() -> UIMenu {
        UIMenu(
            title: "Chrome",
            children: MiniBrowserHarnessState.ChromeMode.allCases.map { chromeMode in
                UIAction(
                    title: chromeMode.displayName,
                    state: chromeMode == state.chromeMode ? .on : .off
                ) { [weak self] _ in
                    self?.setChromeMode(chromeMode)
                }
            }
        )
    }

    private func setScenario(_ scenario: MiniBrowserHarnessState.Scenario) {
        state.applyScenario(scenario)
        scheduleSnapshotRefresh(includePage: true)
    }

    private func setChromeMode(_ chromeMode: MiniBrowserHarnessState.ChromeMode) {
        state.applyChromeMode(chromeMode)
        render()
        scheduleSnapshotRefresh(includePage: true)
    }

    private func setAttached(_ isAttached: Bool) {
        guard state.isAttached != isAttached else {
            scheduleNativeCapture()
            return
        }
        state.setAttached(isAttached)
        render()
        scheduleNativeCapture()
    }

    private func reloadFixture() {
        state.reloadFixture()
    }

    private func focusBottomInput() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await state.focusBottomInputForSelfTest()
                flushLayout()
                try await state.scrollBottomInputIntoViewAndRefreshPageMetrics()
                state.captureNativeMetrics(in: self)
            } catch {
                state.markPageMetricsError(error.localizedDescription)
                state.captureNativeMetrics(in: self)
            }
        }
    }

    private func applyChrome(animated: Bool) {
        navigationController?.setNavigationBarHidden(state.chromeMode.isNavigationBarHidden, animated: animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }

    private func scheduleNativeCapture() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.state.captureNativeMetrics(in: self)
        }
    }

    private func scheduleSnapshotRefresh(includePage: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                do {
                    try await self.refreshSnapshot(includePage: includePage)
                } catch {
                    self.state.markPageMetricsError(error.localizedDescription)
                    self.state.captureNativeMetrics(in: self)
                }
            }
        }
    }

    @discardableResult
    private func refreshSnapshot(
        includePage: Bool
    ) async throws -> (
        native: MiniBrowserHarnessState.NativeMetrics,
        page: MiniBrowserHarnessState.PageMetrics?
    ) {
        flushLayout()
        let native = state.captureNativeMetrics(in: self)
        guard includePage else {
            return (native, nil)
        }
        let page = try await state.refreshPageMetrics()
        let refreshedNative = state.captureNativeMetrics(in: self)
        return (refreshedNative, page)
    }

    private func flushLayout() {
        navigationController?.view.setNeedsLayout()
        navigationController?.view.layoutIfNeeded()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        webViewContainerView.setNeedsLayout()
        webViewContainerView.layoutIfNeeded()
        state.webView.setNeedsLayout()
        state.webView.layoutIfNeeded()
    }
}

@MainActor
extension MiniBrowserHarnessViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === state.webView else {
            return
        }
        state.markFixtureLoaded()
        scheduleSnapshotRefresh(includePage: true)
        startSelfTestIfReady()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === state.webView else {
            return
        }
        state.markPageMetricsError(error.localizedDescription)
        scheduleNativeCapture()
        startSelfTestIfReady()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === state.webView else {
            return
        }
        state.markPageMetricsError(error.localizedDescription)
        scheduleNativeCapture()
        startSelfTestIfReady()
    }
}

private extension MiniBrowserHarnessViewController {
    typealias NativeMetrics = MiniBrowserHarnessState.NativeMetrics
    typealias PageMetrics = MiniBrowserHarnessState.PageMetrics

    func startSelfTestIfReady() {
        guard state.selfTestMode == .viewport else {
            return
        }
        guard didStartSelfTest == false, view.window != nil else {
            return
        }

        startSelfTestWatchdog()
        if state.pageMetrics.status == "error" {
            didStartSelfTest = true
            finishSelfTest(
                status: "failed",
                checks: currentSelfTestChecks,
                failure: state.pageMetrics.errorMessage ?? "fixture-load-failed",
                nativeMetrics: state.nativeMetrics,
                pageMetrics: state.pageMetrics,
                exitCode: 1
            )
        }

        guard state.fixtureLoaded else {
            return
        }

        didStartSelfTest = true
        selfTestTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await runViewportSelfTestAndExit()
        }
    }

    func startSelfTestWatchdog() {
        guard selfTestWatchdog == nil else {
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 60)
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            let failure = self.state.fixtureLoaded ? "deadlock-watchdog" : "fixture-load-timeout"
            self.finishSelfTest(
                status: "failed",
                checks: self.currentSelfTestChecks,
                failure: failure,
                nativeMetrics: self.state.nativeMetrics,
                pageMetrics: self.state.pageMetrics,
                exitCode: 1
            )
        }
        timer.resume()
        selfTestWatchdog = timer
    }

    func runViewportSelfTestAndExit() async {
        var checks: [String] = []
        currentSelfTestChecks = checks
        currentSelfTestSnapshots = []
        do {
            let finalMetrics = try await runViewportSelfTest(checks: &checks)
            finishSelfTest(
                status: "passed",
                checks: checks,
                failure: nil,
                nativeMetrics: finalMetrics.native,
                pageMetrics: finalMetrics.page,
                exitCode: 0
            )
        } catch {
            finishSelfTest(
                status: "failed",
                checks: checks,
                failure: String(describing: error),
                nativeMetrics: state.nativeMetrics,
                pageMetrics: state.pageMetrics,
                exitCode: 1
            )
        }
    }

    func runViewportSelfTest(checks: inout [String]) async throws -> (native: NativeMetrics, page: PageMetrics) {
        let initial = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("initial", initial)
        let initialPage = try requirePage(initial.page)
        try check("initial scenario", initial.native.scenario == MiniBrowserHarnessState.Scenario.standard.rawValue, checks: &checks)
        try check("initial chrome", initial.native.chromeMode == MiniBrowserHarnessState.ChromeMode.navigationBarHidden.rawValue, checks: &checks)
        try check("initial attachment", initial.native.attached && initial.native.windowAttached, checks: &checks)
        try check("initial page top", initialPage.topMarkerTop >= 0, checks: &checks)
        try checkFixedBottomWithinViewport("initial", initialPage, checks: &checks)

        state.applyChromeMode(.navigationBarVisible)
        render()
        let chromeVisible = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("navigation", chromeVisible)
        let chromeVisiblePage = try requirePage(chromeVisible.page)
        try check("navigation chrome", chromeVisible.native.chromeMode == MiniBrowserHarnessState.ChromeMode.navigationBarVisible.rawValue, checks: &checks)
        try checkFixedBottomWithinViewport("navigation", chromeVisiblePage, checks: &checks)
        try check(
            "navigation viewport height decreased",
            chromeVisiblePage.viewportHeight < initialPage.viewportHeight,
            "navigation did not reduce visual viewport height: initial=\(initialPage.viewportHeight), navigation=\(chromeVisiblePage.viewportHeight)",
            checks: &checks
        )

        state.applyScenario(.excludeTopSafeArea)
        render()
        let excluded = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("excludeTopSafeArea", excluded)
        let excludedPage = try requirePage(excluded.page)
        try check("exclude top scenario", excluded.native.scenario == MiniBrowserHarnessState.Scenario.excludeTopSafeArea.rawValue, checks: &checks)
        try checkFixedBottomWithinViewport("exclude top", excludedPage, checks: &checks)
        try check(
            "exclude top page stability",
            abs(excludedPage.topMarkerTop - chromeVisiblePage.topMarkerTop) <= 2,
            "excludeTopSafeArea changed topMarkerTop: visible=\(chromeVisiblePage.topMarkerTop), excluded=\(excludedPage.topMarkerTop)",
            checks: &checks
        )

        state.applyScenario(.standard)
        render()
        let standardRestored = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("standardRestored", standardRestored)

        state.applyChromeMode(.navigationBarHidden)
        render()
        let chromeHidden = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("chromeHidden", chromeHidden)
        let chromeHiddenPage = try requirePage(chromeHidden.page)
        try check("restored chrome hidden", chromeHidden.native.chromeMode == MiniBrowserHarnessState.ChromeMode.navigationBarHidden.rawValue, checks: &checks)
        try checkFixedBottomWithinViewport("restored", chromeHiddenPage, checks: &checks)
        try check(
            "restored viewport height increased",
            chromeHiddenPage.viewportHeight > chromeVisiblePage.viewportHeight,
            "restored viewport did not grow after hiding chrome: navigation=\(chromeVisiblePage.viewportHeight), restored=\(chromeHiddenPage.viewportHeight)",
            checks: &checks
        )

        if #available(iOS 26.0, *) {
            return try await runModernViewportSelfTest(
                reattachBaselinePage: chromeHiddenPage,
                checks: &checks
            )
        }

        return try await runLegacyKeyboardSelfTest(
            baselineNative: chromeHidden.native,
            checks: &checks
        )
    }

    @available(iOS 26.0, *)
    func runModernViewportSelfTest(
        reattachBaselinePage: PageMetrics,
        checks: inout [String]
    ) async throws -> (native: NativeMetrics, page: PageMetrics) {
        state.setAttached(false)
        render()
        flushLayout()
        let detachedNative = state.captureNativeMetrics(in: self)
        recordSelfTestSnapshot("detached", native: detachedNative, page: nil)
        try check("modern detached", detachedNative.attached == false && detachedNative.windowAttached == false, checks: &checks)

        state.setAttached(true)
        render()
        let reattached = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("reattached", reattached)
        let reattachedPage = try requirePage(reattached.page)
        try check("modern reattached", reattached.native.attached && reattached.native.windowAttached, checks: &checks)
        try checkFixedBottomWithinViewport("modern reattached", reattachedPage, checks: &checks)
        try check(
            "modern reattached page stability",
            abs(reattachedPage.viewportHeight - reattachBaselinePage.viewportHeight) <= 1,
            "reattached viewport height changed: baseline=\(reattachBaselinePage.viewportHeight), reattached=\(reattachedPage.viewportHeight)",
            checks: &checks
        )

        state.applyScenario(.neverAdjustment)
        render()
        let never = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("neverAdjustment", never)
        let neverPage = try requirePage(never.page)
        try check("modern never scenario", never.native.scenario == MiniBrowserHarnessState.Scenario.neverAdjustment.rawValue, checks: &checks)
        try checkFixedBottomWithinViewport("modern never", neverPage, checks: &checks)
        try check(
            "modern never page stability",
            abs(neverPage.viewportHeight - reattachedPage.viewportHeight) <= 1,
            "neverAdjustment viewport height changed: reattached=\(reattachedPage.viewportHeight), never=\(neverPage.viewportHeight)",
            checks: &checks
        )

        state.applyScenario(.standard)
        render()
        let standard = try await refreshSnapshot(includePage: true)
        recordSelfTestSnapshot("standardBeforeKeyboard", standard)
        let standardPage = try requirePage(standard.page)
        let focused = try await focusBottomInputAndCapture()
        recordSelfTestSnapshot("focused", native: focused.native, page: focused.page)
        try check("modern keyboard active element", focused.page.activeElement == "bottom-input", checks: &checks)
        try check("modern keyboard input visible", focused.page.bottomInputBottom <= focused.page.viewportHeight, checks: &checks)
        try check("modern keyboard height", focused.keyboardHeight > 0, checks: &checks)
        try check(
            "modern keyboard viewport height decreased",
            focused.page.viewportHeight < standardPage.viewportHeight,
            "keyboard did not reduce visual viewport height: standard=\(standardPage.viewportHeight), focused=\(focused.page.viewportHeight)",
            checks: &checks
        )
        try check("modern fixed bottom", focused.page.fixedBottomWithinViewport, checks: &checks)
        return (focused.native, focused.page)
    }

    func runLegacyKeyboardSelfTest(
        baselineNative: NativeMetrics,
        checks: inout [String]
    ) async throws -> (native: NativeMetrics, page: PageMetrics) {
        let focused = try await focusBottomInputAndCapture()
        recordSelfTestSnapshot("focused", native: focused.native, page: focused.page)
        let keyboardHeight = focused.keyboardHeight
        let bottomInsetDelta = focused.native.adjustedBottom - baselineNative.adjustedBottom

        try check("legacy keyboard active element", focused.page.activeElement == "bottom-input", checks: &checks)
        try check("legacy keyboard input visible", focused.page.bottomInputBottom <= focused.page.viewportHeight, checks: &checks)
        try check("legacy keyboard height", keyboardHeight > 0, checks: &checks)
        try check(
            "legacy keyboard inset delta",
            bottomInsetDelta < Int((Double(keyboardHeight) * 1.6).rounded()),
            "legacy path added too much bottom inset: keyboard=\(keyboardHeight), delta=\(bottomInsetDelta)",
            checks: &checks
        )
        return (focused.native, focused.page)
    }

    func focusBottomInputAndCapture() async throws -> (
        native: NativeMetrics,
        page: PageMetrics,
        keyboardHeight: Int
    ) {
        let keyboardObserver = KeyboardFrameObserver()
        let inputSessionBaseline = state.selfTestInputSessionStartCount
        try await state.focusBottomInputForSelfTest()
        let keyboardFrame = try await keyboardObserver.nextFrame()
        flushLayout()
        let page = try await state.scrollBottomInputIntoViewAndRefreshPageMetrics()
        let native = state.captureNativeMetrics(in: self)
        guard let window = state.webView.window else {
            throw MiniBrowserSelfTestFailure(message: "web view detached while showing keyboard")
        }
        let keyboardFrameInWindow = window.convert(keyboardFrame, from: window.screen.coordinateSpace)
        let keyboardHeight = Int(window.bounds.intersection(keyboardFrameInWindow).height.rounded())
        if state.shouldRequireSelfTestInputSessionStart {
            guard state.selfTestInputSessionStartCount > inputSessionBaseline else {
                throw MiniBrowserSelfTestFailure(message: "keyboard input session did not start")
            }
        }
        return (native, page, keyboardHeight)
    }

    @discardableResult
    func requirePage(_ page: PageMetrics?) throws -> PageMetrics {
        guard let page else {
            throw MiniBrowserSelfTestFailure(message: "missing page metrics")
        }
        guard page.status == "ready" else {
            throw MiniBrowserSelfTestFailure(message: "page metrics not ready: \(page)")
        }
        return page
    }

    func checkFixedBottomWithinViewport(
        _ label: String,
        _ page: PageMetrics?,
        checks: inout [String]
    ) throws {
        let page = try requirePage(page)
        try check(
            "\(label) fixed bottom",
            page.fixedBottomWithinViewport,
            "\(label) fixed bottom did not settle: viewportHeight=\(page.viewportHeight), fixedBottomBottom=\(page.fixedBottomBottom)",
            checks: &checks
        )
    }

    func check(
        _ name: String,
        _ condition: @autoclosure () -> Bool,
        _ failureMessage: String? = nil,
        checks: inout [String]
    ) throws {
        guard condition() else {
            throw MiniBrowserSelfTestFailure(message: failureMessage ?? "check failed: \(name)")
        }
        checks.append(name)
        currentSelfTestChecks = checks
    }

    func recordSelfTestSnapshot(
        _ label: String,
        _ snapshot: (native: NativeMetrics, page: PageMetrics?)
    ) {
        recordSelfTestSnapshot(label, native: snapshot.native, page: snapshot.page)
    }

    func recordSelfTestSnapshot(
        _ label: String,
        native: NativeMetrics,
        page: PageMetrics?
    ) {
        currentSelfTestSnapshots.append(
            MiniBrowserSelfTestSnapshot(
                label: label,
                nativeMetrics: native,
                pageMetrics: page
            )
        )
    }

    func finishSelfTest(
        status: String,
        checks: [String],
        failure: String?,
        nativeMetrics: NativeMetrics,
        pageMetrics: PageMetrics,
        exitCode: Int32
    ) -> Never {
        selfTestWatchdog?.cancel()
        selfTestWatchdog = nil

        let result = MiniBrowserSelfTestResult(
            status: status,
            checks: checks,
            failure: failure,
            nativeMetrics: nativeMetrics,
            pageMetrics: pageMetrics,
            snapshots: currentSelfTestSnapshots
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json: String
        if let data = try? encoder.encode(result), let encodedJSON = String(data: data, encoding: .utf8) {
            json = encodedJSON
        } else {
            json = "{\"failure\":\"encoding-failed\",\"status\":\"failed\"}"
        }
        writeSelfTestResult(json)
        print("MINIBROWSER_SELF_TEST_RESULT \(json)")
        fflush(stdout)
        exit(exitCode)
    }

    private func writeSelfTestResult(_ json: String) {
        guard let path = ProcessInfo.processInfo.environment["MINIBROWSER_SELF_TEST_RESULT_PATH"], path.isEmpty == false else {
            return
        }

        do {
            try Data((json + "\n").utf8).write(to: URL(fileURLWithPath: path))
        } catch {
            fputs("MiniBrowser self-test result write failed: \(error)\n", stderr)
            fflush(stderr)
        }
    }

}

private struct MiniBrowserViewportRuntimeDiagnostics: Equatable {
    var publicObscuredContentInsets: UIEdgeInsets?
    var privateObscuredInsets: UIEdgeInsets?
    var computedObscuredInset: UIEdgeInsets?
    var computedUnobscuredSafeAreaInset: UIEdgeInsets?
    var scrollViewSystemContentInset: UIEdgeInsets?
    var scrollViewPrivateSystemContentInset: UIEdgeInsets?
    var webViewSafeAreaInsets: UIEdgeInsets
    var minimumViewportInset: UIEdgeInsets
    var maximumViewportInset: UIEdgeInsets
    var haveSetObscuredInsets: Bool?
    var haveSetUnobscuredSafeAreaInsets: Bool?
}

@MainActor
private enum MiniBrowserViewportRuntimeDiagnosticsReader {
    static func capture(for webView: WKWebView) -> MiniBrowserViewportRuntimeDiagnostics {
        let publicObscuredContentInsets: UIEdgeInsets?
        if #available(iOS 26.0, *) {
            publicObscuredContentInsets = webView.obscuredContentInsets
        } else {
            publicObscuredContentInsets = nil
        }

        return MiniBrowserViewportRuntimeDiagnostics(
            publicObscuredContentInsets: publicObscuredContentInsets,
            privateObscuredInsets: MiniBrowserViewportRuntimeSPIInvocation.readInsets(
                MiniBrowserViewportRuntimeSPI.obscuredInsets,
                from: webView
            ),
            computedObscuredInset: MiniBrowserViewportRuntimeSPIInvocation.readInsets(
                MiniBrowserViewportRuntimeSPI.computedObscuredInset,
                from: webView
            ),
            computedUnobscuredSafeAreaInset: MiniBrowserViewportRuntimeSPIInvocation.readInsets(
                MiniBrowserViewportRuntimeSPI.computedUnobscuredSafeAreaInset,
                from: webView
            ),
            scrollViewSystemContentInset: MiniBrowserViewportRuntimeSPIInvocation.readInsets(
                MiniBrowserViewportRuntimeSPI.scrollViewSystemContentInset,
                from: webView
            ),
            scrollViewPrivateSystemContentInset: MiniBrowserViewportRuntimeSPIInvocation.readInsets(
                MiniBrowserViewportRuntimeSPI.systemContentInset,
                from: webView.scrollView
            ),
            webViewSafeAreaInsets: webView.safeAreaInsets,
            minimumViewportInset: webView.minimumViewportInset,
            maximumViewportInset: webView.maximumViewportInset,
            haveSetObscuredInsets: MiniBrowserViewportRuntimeSPIInvocation.readBool(
                MiniBrowserViewportRuntimeSPI.haveSetObscuredInsets,
                from: webView
            ),
            haveSetUnobscuredSafeAreaInsets: MiniBrowserViewportRuntimeSPIInvocation.readBool(
                MiniBrowserViewportRuntimeSPI.haveSetUnobscuredSafeAreaInsets,
                from: webView
            )
        )
    }
}

private enum MiniBrowserViewportRuntimeSPI {
    static let obscuredInsets = NSSelectorFromString("_obscuredInsets")
    static let computedObscuredInset = NSSelectorFromString("_computedObscuredInset")
    static let computedUnobscuredSafeAreaInset = NSSelectorFromString("_computedUnobscuredSafeAreaInset")
    static let scrollViewSystemContentInset = NSSelectorFromString("_scrollViewSystemContentInset")
    static let systemContentInset = NSSelectorFromString("_systemContentInset")
    static let haveSetObscuredInsets = NSSelectorFromString("_haveSetObscuredInsets")
    static let haveSetUnobscuredSafeAreaInsets = NSSelectorFromString("_haveSetUnobscuredSafeAreaInsets")
}

private enum MiniBrowserViewportRuntimeSPIInvocation {
    typealias InsetsGetter = @convention(c) (NSObject, Selector) -> UIEdgeInsets
    typealias BoolGetter = @convention(c) (NSObject, Selector) -> Bool

    static func readInsets(_ selector: Selector, from object: NSObject) -> UIEdgeInsets? {
        guard object.responds(to: selector) else {
            return nil
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: InsetsGetter.self)
        return implementation(object, selector)
    }

    static func readBool(_ selector: Selector, from object: NSObject) -> Bool? {
        guard object.responds(to: selector) else {
            return nil
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: BoolGetter.self)
        return implementation(object, selector)
    }
}

private struct MiniBrowserSelfTestSnapshot: Codable {
    var label: String
    var nativeMetrics: MiniBrowserHarnessState.NativeMetrics
    var pageMetrics: MiniBrowserHarnessState.PageMetrics?
}

private struct MiniBrowserSelfTestResult: Codable {
    var status: String
    var checks: [String]
    var failure: String?
    var nativeMetrics: MiniBrowserHarnessState.NativeMetrics
    var pageMetrics: MiniBrowserHarnessState.PageMetrics
    var snapshots: [MiniBrowserSelfTestSnapshot]
}

private struct MiniBrowserSelfTestFailure: Error, CustomStringConvertible {
    var message: String

    var description: String {
        message
    }
}

@MainActor
private final class KeyboardFrameObserver {
    private let notificationCenter: NotificationCenter
    private let frames: AsyncStream<CGRect>
    private let continuation: AsyncStream<CGRect>.Continuation
    private var observer: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        let (frames, continuation) = AsyncStream<CGRect>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.frames = frames
        self.continuation = continuation
        observer = notificationCenter.addObserver(
            forName: UIResponder.keyboardDidShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .null
            continuation.yield(frame)
            continuation.finish()
        }
    }

    isolated deinit {
        invalidate()
    }

    func nextFrame() async throws -> CGRect {
        defer { invalidate() }
        var iterator = frames.makeAsyncIterator()
        guard let frame = await iterator.next() else {
            throw CancellationError()
        }
        return frame
    }

    private func invalidate() {
        if let observer {
            notificationCenter.removeObserver(observer)
            self.observer = nil
        }
        continuation.finish()
    }
}
