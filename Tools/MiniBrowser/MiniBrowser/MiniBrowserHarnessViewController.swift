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
        var expectedTop: Int
        var expectedBottom: Int
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
    let commandSessionID: String
    private(set) var scenario: Scenario
    private(set) var chromeMode: ChromeMode
    private(set) var isAttached = true
    private(set) var fixtureLoaded = false
    private(set) var nativeMetrics: NativeMetrics
    private(set) var pageMetrics = PageMetrics.idle
    private var nextPageMetricsRequestID = 0
    private var pageMetricsGeneration = 0

    init(processInfo: ProcessInfo = .processInfo) {
        let initialScenario = Scenario(rawValue: processInfo.environment["MINIBROWSER_SCENARIO"] ?? "") ?? .standard
        let initialChromeMode = ChromeMode(rawValue: processInfo.environment["MINIBROWSER_CHROME_MODE"] ?? "") ?? .navigationBarHidden
        let commandSessionID = processInfo.environment["MINIBROWSER_COMMAND_SESSION"] ?? UUID().uuidString
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = ManagedViewportWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true

        self.webView = webView
        self.commandSessionID = commandSessionID
        scenario = initialScenario
        chromeMode = initialChromeMode
        nativeMetrics = NativeMetrics.idle(for: initialScenario, chromeMode: initialChromeMode)
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

        pageMetricsGeneration += 1
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

    func applyChromeMode(_ chromeMode: ChromeMode) {
        self.chromeMode = chromeMode
        nativeMetrics.chromeMode = chromeMode.rawValue
    }

    func toggleAttachment() {
        isAttached.toggle()
    }

    func captureNativeMetrics(in hostViewController: UIViewController) {
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
        let expectedInsets = expectedInsets(in: hostViewController, attached: attached && windowAttached)

        nativeMetrics = NativeMetrics(
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
            expectedTop: expectedInsets.top,
            expectedBottom: expectedInsets.bottom,
            errorMessage: nil
        )
    }

    func capturePageMetrics() async {
        guard fixtureLoaded else {
            setPageMetricsLoading()
            return
        }

        do {
            let requestID = makePageMetricsRequestID()
            let generation = pageMetricsGeneration
            try await evaluateJavaScriptVoid("window.testHarness.requestStateCapture(\(requestID));")
            let rawJSON = try await nextPendingPageMetricsJSON(for: requestID, generation: generation)
            pageMetrics = try decodePageMetrics(from: rawJSON)
        } catch {
            handlePageMetricsFailure(error)
        }
    }

    func focusBottomInput() async {
        guard fixtureLoaded else {
            setPageMetricsLoading()
            return
        }

        do {
            let requestID = makePageMetricsRequestID()
            let generation = pageMetricsGeneration
            try await evaluateJavaScriptVoid("window.testHarness.focusInput('bottom-input', \(requestID));")
            let rawJSON = try await nextPendingPageMetricsJSON(for: requestID, generation: generation)
            pageMetrics = try decodePageMetrics(from: rawJSON)
        } catch {
            handlePageMetricsFailure(error)
        }
    }

    func markPageMetricsError(_ message: String) {
        pageMetricsGeneration += 1
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

    private func makePageMetricsRequestID() -> Int {
        nextPageMetricsRequestID += 1
        return nextPageMetricsRequestID
    }

    private func nextPendingPageMetricsJSON(for requestID: Int, generation: Int) async throws -> String {
        while true {
            if let rawJSON = try await evaluateJavaScriptOptionalString("window.testHarness.takePendingState(\(requestID));") {
                if pageMetricsGeneration != generation {
                    throw PageMetricsError.fixtureReloaded
                }
                return rawJSON
            }
            if fixtureLoaded == false || pageMetricsGeneration != generation {
                throw PageMetricsError.fixtureReloaded
            }
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func evaluateJavaScriptOptionalString(_ script: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if result is NSNull || result == nil {
                    continuation.resume(returning: nil)
                    return
                }
                guard let string = result as? String else {
                    continuation.resume(throwing: PageMetricsError.unexpectedResultType)
                    return
                }
                continuation.resume(returning: string)
            }
        }
    }

    private func evaluateJavaScriptVoid(_ script: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
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

    private func setPageMetricsLoading() {
        pageMetrics = PageMetrics(status: "loading", revision: pageMetrics.revision + 1, activeElement: "", topMarkerTop: -1, topMarkerBottom: -1, bottomInputTop: -1, bottomInputBottom: -1, viewportHeight: -1, bottomWithinViewport: false, errorMessage: nil)
    }

    private func handlePageMetricsFailure(_ error: any Error) {
        if case PageMetricsError.fixtureReloaded = error {
            if pageMetrics.status != "error" {
                setPageMetricsLoading()
            }
            return
        }
        pageMetrics = errorPageMetrics(message: error.localizedDescription)
    }

    private var fixtureURL: URL? {
        Bundle.main.url(forResource: "ViewportFixture", withExtension: "html")
    }

    private func expectedInsets(in hostViewController: UIViewController, attached: Bool) -> (top: Int, bottom: Int) {
        guard attached, hostViewController.viewIfLoaded != nil else {
            return (0, 0)
        }
        let metrics = webView.viewportMetricsProvider.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        return (Self.rounded(metrics.topObscuredHeight), Self.rounded(metrics.bottomObscuredHeight))
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

private enum PageMetricsError: Error {
    case unexpectedResultType
    case fixtureReloaded
}

nonisolated enum MiniBrowserHarnessAttachment: String, CaseIterable, Codable, Sendable {
    case attached
    case detached

    var isAttached: Bool {
        self == .attached
    }
}

nonisolated enum MiniBrowserHarnessCommand: Equatable, Sendable {
    private static let notificationPrefix = "wkviewport.minibrowser.command"
    private static let allowedSessionCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_")
    )

    case setScenario(MiniBrowserHarnessState.Scenario)
    case setChromeMode(MiniBrowserHarnessState.ChromeMode)
    case setAttachment(MiniBrowserHarnessAttachment)
    case reloadFixture
    case focusBottomInput

    func notificationName(for sessionID: String) -> String {
        let encodedSessionID = Self.encodeSessionID(sessionID)
        switch self {
        case .setScenario(let scenario):
            return "\(Self.notificationPrefix).\(encodedSessionID).setScenario.\(scenario.rawValue)"
        case .setChromeMode(let chromeMode):
            return "\(Self.notificationPrefix).\(encodedSessionID).setChromeMode.\(chromeMode.rawValue)"
        case .setAttachment(let attachment):
            return "\(Self.notificationPrefix).\(encodedSessionID).setAttachment.\(attachment.rawValue)"
        case .reloadFixture:
            return "\(Self.notificationPrefix).\(encodedSessionID).reloadFixture"
        case .focusBottomInput:
            return "\(Self.notificationPrefix).\(encodedSessionID).focusBottomInput"
        }
    }

    static func allNotificationNames(for sessionID: String) -> [String] {
        MiniBrowserHarnessState.Scenario.allCases.map(Self.setScenario).map { $0.notificationName(for: sessionID) }
        + MiniBrowserHarnessState.ChromeMode.allCases.map(Self.setChromeMode).map { $0.notificationName(for: sessionID) }
        + MiniBrowserHarnessAttachment.allCases.map(Self.setAttachment).map { $0.notificationName(for: sessionID) }
        + [Self.reloadFixture.notificationName(for: sessionID), Self.focusBottomInput.notificationName(for: sessionID)]
    }

    static func parse(notificationName: String) -> (sessionID: String, command: Self)? {
        let prefix = "\(Self.notificationPrefix)."
        guard notificationName.hasPrefix(prefix) else {
            return nil
        }

        let suffix = String(notificationName.dropFirst(prefix.count))
        let components = suffix.split(separator: ".", maxSplits: 2).map(String.init)
        guard components.count >= 2 else {
            return nil
        }

        guard let sessionID = Self.decodeSessionID(components[0]) else {
            return nil
        }
        let command: Self
        if components[1] == "reloadFixture" {
            return (sessionID, .reloadFixture)
        }
        if components[1] == "focusBottomInput" {
            return (sessionID, .focusBottomInput)
        }

        guard components.count == 3 else {
            return nil
        }

        switch components[1] {
        case "setScenario":
            guard let scenario = MiniBrowserHarnessState.Scenario(rawValue: components[2]) else {
                return nil
            }
            command = .setScenario(scenario)
        case "setChromeMode":
            guard let chromeMode = MiniBrowserHarnessState.ChromeMode(rawValue: components[2]) else {
                return nil
            }
            command = .setChromeMode(chromeMode)
        case "setAttachment":
            guard let attachment = MiniBrowserHarnessAttachment(rawValue: components[2]) else {
                return nil
            }
            command = .setAttachment(attachment)
        default:
            return nil
        }

        return (sessionID, command)
    }

    private static func encodeSessionID(_ sessionID: String) -> String {
        sessionID.addingPercentEncoding(withAllowedCharacters: allowedSessionCharacters) ?? sessionID
    }

    private static func decodeSessionID(_ sessionID: String) -> String? {
        sessionID.removingPercentEncoding
    }
}

@MainActor
final class MiniBrowserHarnessViewController: UIViewController {
    private let state: MiniBrowserHarnessState
    private let webViewContainerView = UIView()
    private let commandReadinessProbeView = HarnessAccessibilityProbeView(identifier: "harness.command.ready")
    private let nativeMetricsProbeView = HarnessAccessibilityProbeView(identifier: "harness.metrics.native")
    private let pageMetricsProbeView = HarnessAccessibilityProbeView(identifier: "harness.metrics.page")
    private var webViewConstraints: [NSLayoutConstraint] = []

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
        MiniBrowserHarnessCommandCenter.shared.attach(self, sessionID: state.commandSessionID)
        commandReadinessProbeView.accessibilityValue = state.commandSessionID
    }

    isolated deinit {
        MiniBrowserHarnessCommandCenter.shared.detach(self)
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
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        scheduleNativeCapture()
    }

    private func configureViewHierarchy() {
        view.backgroundColor = .systemBackground
        webViewContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webViewContainerView)

        [commandReadinessProbeView, nativeMetricsProbeView, pageMetricsProbeView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            webViewContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            webViewContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webViewContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            commandReadinessProbeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            commandReadinessProbeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandReadinessProbeView.widthAnchor.constraint(equalToConstant: 1),
            commandReadinessProbeView.heightAnchor.constraint(equalToConstant: 1),

            nativeMetricsProbeView.topAnchor.constraint(equalTo: commandReadinessProbeView.bottomAnchor),
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
        syncChromeControls()
    }

    private func beginObservation() {
        withObservationTracking {
            _ = state.isAttached
            _ = state.fixtureLoaded
            _ = state.scenario
            _ = state.chromeMode
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

        applyChrome(animated: false)
        syncChromeControls()
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

    private func scenarioMenu() -> UIMenu {
        UIMenu(
            title: "Viewport",
            children: MiniBrowserHarnessState.Scenario.allCases.map { scenario in
                UIAction(
                    title: scenario.displayName,
                    state: scenario == state.scenario ? .on : .off
                ) { [weak self] _ in
                    self?.applyCommand(.setScenario(scenario))
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
                    self?.applyCommand(.reloadFixture)
                },
                UIAction(title: state.isAttached ? "Detach WebView" : "Attach WebView") { [weak self] _ in
                    self?.applyCommand(.setAttachment(self?.state.isAttached == true ? .detached : .attached))
                },
                UIAction(title: "Focus Bottom Input") { [weak self] _ in
                    self?.applyCommand(.focusBottomInput)
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
                    self?.applyCommand(.setChromeMode(chromeMode))
                }
            }
        )
    }

    fileprivate func applyCommand(_ command: MiniBrowserHarnessCommand) {
        switch command {
        case .setScenario(let scenario):
            state.applyScenario(scenario)
            scheduleSnapshotRefresh(includePage: true)
        case .setChromeMode(let chromeMode):
            state.applyChromeMode(chromeMode)
            render()
            scheduleSnapshotRefresh(includePage: true, initialDelay: .milliseconds(200))
        case .setAttachment(let attachment):
            guard state.isAttached != attachment.isAttached else {
                scheduleNativeCapture()
                return
            }
            state.toggleAttachment()
            render()
            scheduleNativeCapture()
        case .reloadFixture:
            state.reloadFixture()
        case .focusBottomInput:
            performFocusBottomInputAction()
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

    private func scheduleSnapshotRefresh(includePage: Bool, initialDelay: Duration = .zero) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if initialDelay > .zero {
                    try? await Task.sleep(for: initialDelay)
                    self.navigationController?.view.layoutIfNeeded()
                    self.view.layoutIfNeeded()
                }
                self.state.captureNativeMetrics(in: self)
                guard includePage else {
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
                await self.state.capturePageMetrics()
                self.state.captureNativeMetrics(in: self)
            }
        }
    }

    private func performFocusBottomInputAction() {
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

@MainActor
private final class MiniBrowserHarnessCommandCenter {
    static let shared = MiniBrowserHarnessCommandCenter()

    private weak var handler: MiniBrowserHarnessViewController?
    private var sessionID: String?
    private var observedNotificationNames: [String] = []

    private init() {}

    func attach(_ handler: MiniBrowserHarnessViewController, sessionID: String) {
        if self.sessionID != sessionID {
            updateObservedNotifications(for: sessionID)
        }
        self.handler = handler
        self.sessionID = sessionID
    }

    func detach(_ handler: MiniBrowserHarnessViewController) {
        guard self.handler === handler else {
            return
        }
        self.handler = nil
        self.sessionID = nil
        updateObservedNotifications(for: nil)
    }

    nonisolated func handleDarwinNotification(named notificationName: String) {
        Task { @MainActor in
            self.route(notificationName: notificationName)
        }
    }

    private func route(notificationName: String) {
        guard
            let (sessionID, command) = MiniBrowserHarnessCommand.parse(notificationName: notificationName),
            sessionID == self.sessionID,
            let handler
        else {
            return
        }

        handler.applyCommand(command)
    }

    private func updateObservedNotifications(for sessionID: String?) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        for notificationName in observedNotificationNames {
            CFNotificationCenterRemoveObserver(center, nil, CFNotificationName(notificationName as CFString), nil)
        }

        guard let sessionID else {
            observedNotificationNames = []
            return
        }

        let notificationNames = MiniBrowserHarnessCommand.allNotificationNames(for: sessionID)
        for notificationName in notificationNames {
            CFNotificationCenterAddObserver(
                center,
                nil,
                miniBrowserHarnessCommandNotificationCallback,
                notificationName as CFString,
                nil,
                .deliverImmediately
            )
        }
        observedNotificationNames = notificationNames
    }
}

private let miniBrowserHarnessCommandNotificationCallback: CFNotificationCallback = { _, _, name, _, _ in
    guard
        let rawName = name?.rawValue as String?
    else {
        return
    }

    MiniBrowserHarnessCommandCenter.shared.handleDarwinNotification(named: rawName)
}
