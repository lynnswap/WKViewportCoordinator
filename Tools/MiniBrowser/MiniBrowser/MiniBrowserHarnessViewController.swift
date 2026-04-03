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
    enum Scenario: String, CaseIterable, Codable, Sendable {
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

        var viewportConfiguration: ViewportConfiguration {
            var configuration = ViewportConfiguration()
            switch self {
            case .standard:
                break
            case .neverAdjustment:
                configuration.contentInsetAdjustmentBehavior = .never
            case .excludeTopSafeArea:
                configuration.safeAreaAffectedEdges = [.bottom]
            }
            return configuration
        }
    }

    struct NativeMetrics: Codable, Equatable {
        var status: String
        var revision: Int
        var scenario: String
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
        var expectedTop: Int
        var expectedBottom: Int
        var errorMessage: String?

        static func idle(for scenario: Scenario) -> Self {
            Self(
                status: "idle",
                revision: 0,
                scenario: scenario.rawValue,
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
                expectedTop: 0,
                expectedBottom: 0,
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
        var viewportHeight: Int
        var bottomWithinViewport: Bool
        var errorMessage: String?

        static let idle = Self(
            status: "idle",
            revision: 0,
            activeElement: "",
            topMarkerTop: -1,
            topMarkerBottom: -1,
            bottomInputTop: -1,
            bottomInputBottom: -1,
            viewportHeight: -1,
            bottomWithinViewport: false,
            errorMessage: nil
        )
    }

    let webView: ManagedViewportWebView

    private(set) var scenario: Scenario
    private(set) var isAttached = true
    private(set) var fixtureLoaded = false
    private(set) var nativeMetrics: NativeMetrics
    private(set) var pageMetrics = PageMetrics.idle

    init(processInfo: ProcessInfo = .processInfo) {
        let initialScenario = Scenario(rawValue: processInfo.environment["MINIBROWSER_SCENARIO"] ?? "") ?? .standard
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = ManagedViewportWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true

        self.webView = webView
        scenario = initialScenario
        nativeMetrics = NativeMetrics.idle(for: initialScenario)
        webView.viewportConfiguration = initialScenario.viewportConfiguration
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
        pageMetrics = PageMetrics(status: "loading", revision: pageMetrics.revision + 1, activeElement: "", topMarkerTop: -1, topMarkerBottom: -1, bottomInputTop: -1, bottomInputBottom: -1, viewportHeight: -1, bottomWithinViewport: false, errorMessage: nil)
        webView.loadFileURL(fixtureURL, allowingReadAccessTo: fixtureURL.deletingLastPathComponent())
    }

    func markFixtureLoaded() {
        fixtureLoaded = true
    }

    func applyScenario(_ scenario: Scenario) {
        self.scenario = scenario
        webView.viewportConfiguration = scenario.viewportConfiguration
        nativeMetrics.scenario = scenario.rawValue
    }

    func toggleAttachment() {
        isAttached.toggle()
    }

    func captureNativeMetrics(in hostViewController: UIViewController) {
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
        let expectedInsets = expectedInsets(in: hostViewController, attached: attached && windowAttached)

        nativeMetrics = NativeMetrics(
            status: "ready",
            revision: nativeMetrics.revision + 1,
            scenario: scenario.rawValue,
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
            expectedTop: expectedInsets.top,
            expectedBottom: expectedInsets.bottom,
            errorMessage: nil
        )
    }

    func capturePageMetrics() async {
        await executePageMetricsScript("return await window.testHarness.reportState();")
    }

    func focusBottomInput() async {
        await executePageMetricsScript(
            "return await window.testHarness.focusInput(identifier);",
            arguments: ["identifier": "bottom-input"]
        )
    }

    func markPageMetricsError(_ message: String) {
        pageMetrics = errorPageMetrics(message: message)
    }

    private func executePageMetricsScript(_ script: String, arguments: [String: Any] = [:]) async {
        guard fixtureLoaded else {
            pageMetrics = PageMetrics(status: "loading", revision: pageMetrics.revision + 1, activeElement: "", topMarkerTop: -1, topMarkerBottom: -1, bottomInputTop: -1, bottomInputBottom: -1, viewportHeight: -1, bottomWithinViewport: false, errorMessage: nil)
            return
        }

        do {
            let rawResult = try await webView.callAsyncJavaScript(
                script,
                arguments: arguments,
                in: nil,
                contentWorld: .page
            )
            guard let rawJSON = rawResult as? String else {
                pageMetrics = errorPageMetrics(message: "unexpected-page-result")
                return
            }
            pageMetrics = try decodePageMetrics(from: rawJSON)
        } catch {
            pageMetrics = errorPageMetrics(message: error.localizedDescription)
        }
    }

    private func decodePageMetrics(from rawJSON: String) throws -> PageMetrics {
        var metrics = try JSONDecoder().decode(PageMetrics.self, from: Data(rawJSON.utf8))
        metrics.status = "ready"
        metrics.revision = pageMetrics.revision + 1
        metrics.errorMessage = nil
        return metrics
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
            viewportHeight: -1,
            bottomWithinViewport: false,
            errorMessage: message
        )
    }

    private var fixtureURL: URL? {
        Bundle.main.url(forResource: "ViewportFixture", withExtension: "html")
    }

    private func expectedInsets(in hostViewController: UIViewController, attached: Bool) -> (top: Int, bottom: Int) {
        guard attached else {
            return (0, 0)
        }
        let safeAreaInsets = hostViewController.view.safeAreaInsets
        return (Self.rounded(safeAreaInsets.top), Self.rounded(safeAreaInsets.bottom))
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
}

@MainActor
final class MiniBrowserHarnessViewController: UIViewController {
    private let state: MiniBrowserHarnessState
    private let webViewContainerView = UIView()
    private let nativeMetricsProbeView = HarnessAccessibilityProbeView(identifier: "harness.metrics.native")
    private let pageMetricsProbeView = HarnessAccessibilityProbeView(identifier: "harness.metrics.page")
    private var webViewConstraints: [NSLayoutConstraint] = []

    private lazy var reloadFixtureItem = makeBarButtonItem(
        title: "Reload",
        identifier: "harness.action.reloadFixture",
        action: #selector(handleReloadFixture)
    )
    private lazy var focusBottomInputItem = makeBarButtonItem(
        title: "Focus",
        identifier: "harness.action.focusBottomInput",
        action: #selector(handleFocusBottomInput)
    )
    private lazy var toggleAttachmentItem = makeBarButtonItem(
        title: "Detach",
        identifier: "harness.action.toggleAttachment",
        action: #selector(handleToggleAttachment)
    )
    private lazy var scenarioItem: UIBarButtonItem = {
        let item = UIBarButtonItem(title: "Scenario", image: nil, primaryAction: nil, menu: scenarioMenu())
        item.accessibilityIdentifier = "harness.action.scenarioMenu"
        return item
    }()

    init(state: MiniBrowserHarnessState) {
        self.state = state
        super.init(nibName: nil, bundle: nil)
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
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setToolbarHidden(false, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        state.loadFixtureIfNeeded()
        scheduleNativeCapture()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        scheduleNativeCapture()
    }

    private func configureViewHierarchy() {
        view.backgroundColor = .systemBackground
        webViewContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webViewContainerView)

        [nativeMetricsProbeView, pageMetricsProbeView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            webViewContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            webViewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webViewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            nativeMetricsProbeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            nativeMetricsProbeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nativeMetricsProbeView.widthAnchor.constraint(equalToConstant: 1),
            nativeMetricsProbeView.heightAnchor.constraint(equalToConstant: 1),

            pageMetricsProbeView.topAnchor.constraint(equalTo: nativeMetricsProbeView.bottomAnchor),
            pageMetricsProbeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageMetricsProbeView.widthAnchor.constraint(equalToConstant: 1),
            pageMetricsProbeView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func configureChrome() {
        navigationItem.title = "MiniBrowser"
        navigationItem.rightBarButtonItems = [reloadFixtureItem]
        navigationItem.leftBarButtonItem = scenarioItem
        setToolbarItems(
            [
                toggleAttachmentItem,
                .flexibleSpace(),
                focusBottomInputItem
            ],
            animated: false
        )
    }

    private func beginObservation() {
        withObservationTracking {
            _ = state.isAttached
            _ = state.fixtureLoaded
            _ = state.scenario
            _ = state.nativeMetricsJSON
            _ = state.pageMetricsJSON
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

        toggleAttachmentItem.title = state.isAttached ? "Detach" : "Attach"
        toggleAttachmentItem.accessibilityLabel = toggleAttachmentItem.title
        scenarioItem.menu = scenarioMenu()
        nativeMetricsProbeView.accessibilityValue = state.nativeMetricsJSON
        pageMetricsProbeView.accessibilityValue = state.pageMetricsJSON
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

    private func makeBarButtonItem(title: String, identifier: String, action: Selector) -> UIBarButtonItem {
        let item = UIBarButtonItem(title: title, style: .plain, target: self, action: action)
        item.accessibilityIdentifier = identifier
        return item
    }

    private func scenarioMenu() -> UIMenu {
        UIMenu(
            title: "Scenario",
            children: MiniBrowserHarnessState.Scenario.allCases.map { scenario in
                UIAction(
                    title: scenario.displayName,
                    state: scenario == state.scenario ? .on : .off
                ) { [weak self] _ in
                    self?.applyScenario(scenario)
                }
            }
        )
    }

    private func applyScenario(_ scenario: MiniBrowserHarnessState.Scenario) {
        state.applyScenario(scenario)
        scheduleSnapshotRefresh(includePage: true)
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
            self.state.captureNativeMetrics(in: self)
            guard includePage else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
                await self.state.capturePageMetrics()
                self.state.captureNativeMetrics(in: self)
            }
        }
    }

    @objc
    private func handleReloadFixture() {
        state.reloadFixture()
    }

    @objc
    private func handleFocusBottomInput() {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await state.focusBottomInput()
            try? await Task.sleep(for: .milliseconds(250))
            state.captureNativeMetrics(in: self)
            await state.capturePageMetrics()
        }
    }

    @objc
    private func handleToggleAttachment() {
        state.toggleAttachment()
        render()
        scheduleNativeCapture()
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
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === state.webView else {
            return
        }
        state.markPageMetricsError(error.localizedDescription)
        scheduleNativeCapture()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === state.webView else {
            return
        }
        state.markPageMetricsError(error.localizedDescription)
        scheduleNativeCapture()
    }
}

private final class HarnessAccessibilityProbeView: UILabel {
    init(identifier: String) {
        super.init(frame: .zero)
        isAccessibilityElement = true
        accessibilityIdentifier = identifier
        accessibilityTraits = .staticText
        accessibilityLabel = identifier
        accessibilityValue = "{}"
        text = "."
        textColor = .clear
        backgroundColor = .clear
        font = .systemFont(ofSize: 1)
        alpha = 1
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
