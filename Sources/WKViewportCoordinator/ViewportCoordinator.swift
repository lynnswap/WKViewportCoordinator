#if canImport(UIKit)
import Combine
import UIKit
import WebKit

public enum BottomChromeMode: Equatable {
    case normal
    case hiddenForKeyboard
}

public enum ScrollEdgeEffectStyle: Equatable {
    case automatic
    case hard
    case soft
}

public struct ViewportConfiguration: Equatable {
    public var contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior
    public var topEdgeEffectHidden: Bool
    public var bottomEdgeEffectHidden: Bool
    public var topEdgeEffectStyle: ScrollEdgeEffectStyle
    public var bottomEdgeEffectStyle: ScrollEdgeEffectStyle
    public var safeAreaAffectedEdges: UIRectEdge

    public init(
        contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior = .always,
        topEdgeEffectHidden: Bool = false,
        bottomEdgeEffectHidden: Bool = false,
        topEdgeEffectStyle: ScrollEdgeEffectStyle = .soft,
        bottomEdgeEffectStyle: ScrollEdgeEffectStyle = .soft,
        safeAreaAffectedEdges: UIRectEdge = [.top, .bottom]
    ) {
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        self.topEdgeEffectHidden = topEdgeEffectHidden
        self.bottomEdgeEffectHidden = bottomEdgeEffectHidden
        self.topEdgeEffectStyle = topEdgeEffectStyle
        self.bottomEdgeEffectStyle = bottomEdgeEffectStyle
        self.safeAreaAffectedEdges = safeAreaAffectedEdges
    }
}

public struct ViewportMetrics: Equatable {
    public var safeAreaInsets: UIEdgeInsets
    public var topObscuredHeight: CGFloat
    public var bottomObscuredHeight: CGFloat
    public var keyboardOverlapHeight: CGFloat
    public var inputAccessoryOverlapHeight: CGFloat
    public var bottomChromeMode: BottomChromeMode
    public var safeAreaAffectedEdges: UIRectEdge

    public init(
        safeAreaInsets: UIEdgeInsets,
        topObscuredHeight: CGFloat,
        bottomObscuredHeight: CGFloat,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat,
        bottomChromeMode: BottomChromeMode,
        safeAreaAffectedEdges: UIRectEdge = [.top, .bottom]
    ) {
        self.safeAreaInsets = safeAreaInsets
        self.topObscuredHeight = topObscuredHeight
        self.bottomObscuredHeight = bottomObscuredHeight
        self.keyboardOverlapHeight = keyboardOverlapHeight
        self.inputAccessoryOverlapHeight = inputAccessoryOverlapHeight
        self.bottomChromeMode = bottomChromeMode
        self.safeAreaAffectedEdges = safeAreaAffectedEdges
    }

    public var finalObscuredInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, topObscuredHeight),
            left: 0,
            bottom: resolvedBottomObscuredHeight,
            right: 0
        )
    }

    private var resolvedBottomObscuredHeight: CGFloat {
        let overlayHeight = bottomChromeMode == .normal ? bottomObscuredHeight : 0
        return max(0, overlayHeight, keyboardOverlapHeight, inputAccessoryOverlapHeight)
    }
}

struct ResolvedViewportMetrics: Equatable {
    let safeAreaInsets: UIEdgeInsets
    let obscuredInsets: UIEdgeInsets
    let unobscuredSafeAreaInsets: UIEdgeInsets
    let safeAreaAffectedEdges: UIRectEdge
    let contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior

    init(
        state: ViewportMetrics,
        contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior,
        screenScale: CGFloat
    ) {
        safeAreaInsets = state.safeAreaInsets.wk_roundedToPixel(screenScale)
        obscuredInsets = state.finalObscuredInsets.wk_roundedToPixel(screenScale)
        unobscuredSafeAreaInsets = UIEdgeInsets(
            top: max(0, safeAreaInsets.top - obscuredInsets.top),
            left: max(0, safeAreaInsets.left - obscuredInsets.left),
            bottom: max(0, safeAreaInsets.bottom - obscuredInsets.bottom),
            right: max(0, safeAreaInsets.right - obscuredInsets.right)
        )
        safeAreaAffectedEdges = state.safeAreaAffectedEdges
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
    }

    var contentScrollInsetFallback: UIEdgeInsets {
        let safeAreaInsetContribution = safeAreaInsetContributionForFallback
        return UIEdgeInsets(
            top: max(0, obscuredInsets.top - safeAreaInsetContribution.top),
            left: max(0, obscuredInsets.left - safeAreaInsetContribution.left),
            bottom: max(0, obscuredInsets.bottom - safeAreaInsetContribution.bottom),
            right: max(0, obscuredInsets.right - safeAreaInsetContribution.right)
        )
    }

    private var safeAreaInsetContributionForFallback: UIEdgeInsets {
        guard contentInsetAdjustmentBehavior != .never else {
            return .zero
        }

        return UIEdgeInsets(
            top: safeAreaAffectedEdges.contains(.top) ? safeAreaInsets.top : 0,
            left: safeAreaAffectedEdges.contains(.left) ? safeAreaInsets.left : 0,
            bottom: safeAreaAffectedEdges.contains(.bottom) ? safeAreaInsets.bottom : 0,
            right: safeAreaAffectedEdges.contains(.right) ? safeAreaInsets.right : 0
        )
    }
}

@MainActor
public protocol ViewportMetricsSource {
    func makeViewportMetrics(
        in hostViewController: UIViewController,
        webView: WKWebView,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat
    ) -> ViewportMetrics
}

@MainActor
public final class ViewportMetricsProvider: ViewportMetricsSource {
    public init() {}

    public func makeViewportMetrics(
        in hostViewController: UIViewController,
        webView: WKWebView,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat
    ) -> ViewportMetrics {
        let hostView = webView.superview ?? hostViewController.viewIfLoaded
        let safeAreaInsets = projectedWindowSafeAreaInsets(in: hostView)
        let topObscuredHeight = max(
            safeAreaInsets.top,
            topEdgeObscuredHeight(
                of: hostViewController.navigationController?.navigationBar,
                in: hostView
            )
        )
        let bottomObscuredHeight = max(
            safeAreaInsets.bottom,
            bottomEdgeObscuredHeight(of: hostViewController.tabBarController?.tabBar, in: hostView),
            bottomEdgeObscuredHeight(of: resolvedVisibleToolbar(for: hostViewController), in: hostView)
        )
        return ViewportMetrics(
            safeAreaInsets: safeAreaInsets,
            topObscuredHeight: topObscuredHeight,
            bottomObscuredHeight: bottomObscuredHeight,
            keyboardOverlapHeight: keyboardOverlapHeight,
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight,
            bottomChromeMode: .normal
        )
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

    private func topEdgeObscuredHeight(of chromeView: UIView?, in hostView: UIView?) -> CGFloat {
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
        guard
            hostFrameInWindow.intersects(chromeFrameInWindow)
                || chromeFrameInWindow.maxY > hostFrameInWindow.minY
        else {
            return 0
        }

        return max(0, min(hostFrameInWindow.maxY, chromeFrameInWindow.maxY) - hostFrameInWindow.minY)
    }

    private func bottomEdgeObscuredHeight(of chromeView: UIView?, in hostView: UIView?) -> CGFloat {
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
        guard chromeFrameInWindow.minY < hostFrameInWindow.maxY else {
            return 0
        }
        guard chromeFrameInWindow.maxY >= hostFrameInWindow.maxY else {
            return 0
        }

        return max(0, hostFrameInWindow.maxY - max(hostFrameInWindow.minY, chromeFrameInWindow.minY))
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
}

@MainActor
public final class ViewportCoordinator: NSObject {
    public weak var hostViewController: UIViewController? {
        didSet {
            lastAppliedResolvedMetrics = nil
            updateViewport()
        }
    }
    public weak var webView: WKWebView?
    public var configuration: ViewportConfiguration {
        didSet {
            updateViewport()
        }
    }
    public var metricsProvider: any ViewportMetricsSource {
        didSet {
            lastAppliedResolvedMetrics = nil
            updateViewport()
        }
    }

    private var keyboardFrameInScreen: CGRect = .null
    private var lastAppliedResolvedMetrics: ResolvedViewportMetrics?
    private var observationView: ViewportObservationView?
    private var observationViewConstraints: [NSLayoutConstraint] = []
    private var lastKnownWindowScreen: UIScreen?
    private weak var observedHostViewController: UIViewController?
    private var webViewStateCancellables: Set<AnyCancellable> = []
#if DEBUG
    private var appliedViewportUpdateCount = 0
#endif

#if DEBUG
    var resolvedMetricsForTesting: ResolvedViewportMetrics? {
        lastAppliedResolvedMetrics
    }

    var keyboardFrameInScreenForTesting: CGRect {
        keyboardFrameInScreen
    }

    var hasObservationViewForTesting: Bool {
        observationView != nil
    }

    var appliedViewportUpdateCountForTesting: Int {
        appliedViewportUpdateCount
    }

    var resolvedHostViewControllerForTesting: UIViewController? {
        resolvedHostViewController()
    }

    var observationSuperviewForTesting: UIView? {
        observationView?.superview
    }

    var observationViewForTesting: UIView? {
        observationView
    }
#endif

    public init(
        hostViewController: UIViewController? = nil,
        webView: WKWebView,
        configuration: ViewportConfiguration = .init(),
        metricsProvider: any ViewportMetricsSource = ViewportMetricsProvider()
    ) {
        self.hostViewController = hostViewController
        self.webView = webView
        self.configuration = configuration
        self.metricsProvider = metricsProvider
        super.init()
        observeKeyboardNotifications()
        observeWebViewStateIfPossible()
        updateViewport()
    }

    public convenience init(
        webView: WKWebView,
        configuration: ViewportConfiguration = .init(),
        metricsProvider: any ViewportMetricsSource = ViewportMetricsProvider()
    ) {
        self.init(
            hostViewController: nil,
            webView: webView,
            configuration: configuration,
            metricsProvider: metricsProvider
        )
    }

    isolated deinit {
        tearDownViewportCoordination(resetViewport: true)
    }

    public func handleViewDidAppear() {
        updateViewport()
    }

    public func handleWebViewHierarchyDidChange() {
        let currentScreen = webView?.window?.screen
        if let currentScreen, let lastKnownWindowScreen, lastKnownWindowScreen !== currentScreen {
            keyboardFrameInScreen = .null
        }
        if let currentScreen {
            lastKnownWindowScreen = currentScreen
        }
        updateViewport()
    }

    public func handleWebViewSafeAreaInsetsDidChange() {
        lastAppliedResolvedMetrics = nil
        updateViewport()
    }

    public func updateViewport() {
        guard let webView else {
            return
        }
        guard
            let observationContainerView = resolvedObservationContainerView(),
            observationContainerView.window != nil,
            webView.window != nil
        else {
            clearInactiveViewportStateIfNeeded(
                resolvedHostViewController: resolvedHostViewController(),
                webView: webView
            )
            return
        }

        installObservationViewIfPossible(in: observationContainerView)
        let resolvedHostViewController = resolvedHostViewController()

        guard
            let hostViewController = resolvedHostViewController,
            hostViewController.view != nil,
            hostViewController.view.window != nil
        else {
            clearInactiveViewportStateIfNeeded(
                resolvedHostViewController: resolvedHostViewController,
                webView: webView
            )
            return
        }

        updateObservedHostViewControllerIfNeeded(hostViewController, webView: webView)

        applyScrollViewConfiguration(to: webView.scrollView)
        hostViewController.setContentScrollView(webView.scrollView)

        var effectiveMetrics = metricsProvider.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: keyboardOverlapHeight(),
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight()
        )
        effectiveMetrics.safeAreaAffectedEdges = configuration.safeAreaAffectedEdges

        let screenScale = observationContainerView.window?.screen.scale
            ?? webView.window?.screen.scale
            ?? observationContainerView.traitCollection.displayScale
        lastKnownWindowScreen = observationContainerView.window?.screen ?? webView.window?.screen
        let resolvedMetrics = ResolvedViewportMetrics(
            state: effectiveMetrics,
            contentInsetAdjustmentBehavior: configuration.contentInsetAdjustmentBehavior,
            screenScale: screenScale
        )
        guard resolvedMetrics != lastAppliedResolvedMetrics else {
            return
        }

        lastAppliedResolvedMetrics = resolvedMetrics
#if DEBUG
        appliedViewportUpdateCount += 1
#endif
        if #available(iOS 26.0, *) {
            webView.obscuredContentInsets = resolvedMetrics.obscuredInsets
            ViewportSPIBridge.apply(
                unobscuredSafeAreaInsets: resolvedMetrics.unobscuredSafeAreaInsets,
                to: webView
            )
            ViewportSPIBridge.apply(
                obscuredSafeAreaEdges: resolvedMetrics.safeAreaAffectedEdges,
                to: webView
            )
        } else {
            ViewportSPIBridge.applyContentScrollInsetFallback(
                resolvedMetrics.contentScrollInsetFallback,
                to: webView.scrollView,
                webView: webView
            )
        }
    }

    public func invalidate() {
        tearDownViewportCoordination(resetViewport: true)
    }

    private func tearDownViewportCoordination(resetViewport: Bool) {
        NotificationCenter.default.removeObserver(self)
        webViewStateCancellables.removeAll()
        clearObservationViewIfNeeded()

        guard let webView else {
            return
        }

        if resetViewport {
            resetAppliedViewportInsets(on: webView)
        }
        clearObservedScrollViewIfNeeded(on: observedHostViewController ?? hostViewController, webView: webView)
        observedHostViewController = nil
        lastAppliedResolvedMetrics = nil
        lastKnownWindowScreen = nil
    }

    private func applyScrollViewConfiguration(to scrollView: UIScrollView) {
        if scrollView.contentInsetAdjustmentBehavior != configuration.contentInsetAdjustmentBehavior {
            scrollView.contentInsetAdjustmentBehavior = configuration.contentInsetAdjustmentBehavior
        }

        if #available(iOS 26.0, *) {
            scrollView.topEdgeEffect.isHidden = configuration.topEdgeEffectHidden
            scrollView.topEdgeEffect.style = configuration.topEdgeEffectStyle.uiKitStyle
            scrollView.bottomEdgeEffect.isHidden = configuration.bottomEdgeEffectHidden
            scrollView.bottomEdgeEffect.style = configuration.bottomEdgeEffectStyle.uiKitStyle
        }
    }

    private func installObservationViewIfPossible() {
        guard let observationContainerView = resolvedObservationContainerView() else {
            return
        }

        installObservationViewIfPossible(in: observationContainerView)
    }

    private func installObservationViewIfPossible(in hostView: UIView) {
        if observationView?.superview === hostView {
            return
        }

        clearObservationViewIfNeeded()

        let observationView = ViewportObservationView()
        self.observationView = observationView
        observationView.onViewportGeometryChanged = { [weak self, weak observationView] in
            guard let self, let observationView, self.observationView === observationView else {
                return
            }
            self.updateViewport()
        }
        observationView.translatesAutoresizingMaskIntoConstraints = false
        observationView.isUserInteractionEnabled = false
        observationView.backgroundColor = .clear
        if #available(iOS 15.0, *) {
            observationView.keyboardLayoutGuide.followsUndockedKeyboard = true
        }
        hostView.addSubview(observationView)
        hostView.sendSubviewToBack(observationView)

        let constraints = [
            observationView.topAnchor.constraint(equalTo: hostView.topAnchor),
            observationView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            observationView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            observationView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ]
        observationViewConstraints = constraints
        NSLayoutConstraint.activate(constraints)

        observationView.setNeedsLayout()
        observationView.layoutIfNeeded()
    }

    private func resolvedObservationContainerView() -> UIView? {
        webView?.superview
    }

    private func clearInactiveViewportStateIfNeeded(
        resolvedHostViewController: UIViewController?,
        webView: WKWebView
    ) {
        clearObservedScrollViewIfNeeded(
            on: observedHostViewController ?? resolvedHostViewController,
            webView: webView
        )
        observedHostViewController = nil
        lastAppliedResolvedMetrics = nil
        clearObservationViewIfNeeded()
    }

    private func clearObservationViewIfNeeded() {
        NSLayoutConstraint.deactivate(observationViewConstraints)
        observationViewConstraints.removeAll()
        observationView?.onViewportGeometryChanged = nil
        observationView?.removeFromSuperview()
        observationView = nil
    }

    private func resetAppliedViewportInsets(on webView: WKWebView) {
        if #available(iOS 26.0, *) {
            webView.obscuredContentInsets = .zero
            ViewportSPIBridge.apply(unobscuredSafeAreaInsets: .zero, to: webView)
            ViewportSPIBridge.apply(obscuredSafeAreaEdges: [], to: webView)
        } else {
            _ = ViewportSPIBridge.applyContentScrollInsetFallback(.zero, to: webView.scrollView, webView: webView)
        }
    }

    private func resolvedHostViewController() -> UIViewController? {
        if let hostViewController {
            return hostViewController
        }
        guard let webView else {
            return nil
        }

        var responder: UIResponder? = webView
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }

        return webView.window?.rootViewController
    }

    private func updateObservedHostViewControllerIfNeeded(
        _ resolvedHostViewController: UIViewController,
        webView: WKWebView
    ) {
        guard observedHostViewController !== resolvedHostViewController else {
            return
        }

        clearObservedScrollViewIfNeeded(on: observedHostViewController, webView: webView)
        observedHostViewController = resolvedHostViewController
    }

    private func clearObservedScrollViewIfNeeded(on hostViewController: UIViewController?, webView: WKWebView) {
        guard let hostViewController else {
            return
        }

        if hostViewController.contentScrollView(for: .top) === webView.scrollView
            || hostViewController.contentScrollView(for: .bottom) === webView.scrollView {
            hostViewController.setContentScrollView(nil)
        }
    }

    private func observeWebViewStateIfPossible() {
        guard let webView else {
            return
        }

        webView.publisher(for: \.isLoading, options: [.new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleObservedWebViewStateChange()
            }
            .store(in: &webViewStateCancellables)

        webView.publisher(for: \.url, options: [.new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleObservedWebViewStateChange()
            }
            .store(in: &webViewStateCancellables)
    }

    private func handleObservedWebViewStateChange() {
        lastAppliedResolvedMetrics = nil
        updateViewport()
    }

#if DEBUG
    func handleObservedWebViewStateChangeForTesting() {
        handleObservedWebViewStateChange()
    }
#endif

    private func keyboardOverlapHeight() -> CGFloat {
        let frameIntersectionHeight: CGFloat
        if
            let hostView = resolvedHostViewController()?.view,
            let window = hostView.window,
            keyboardFrameInScreen.isNull == false
        {
            let keyboardFrameInWindow = window.convert(
                keyboardFrameInScreen,
                from: window.screen.coordinateSpace
            )
            let keyboardFrameInHostView = hostView.convert(keyboardFrameInWindow, from: nil)
            frameIntersectionHeight = max(0, hostView.bounds.intersection(keyboardFrameInHostView).height)
        } else {
            frameIntersectionHeight = 0
        }

        return max(frameIntersectionHeight, keyboardLayoutGuideCoverageHeight())
    }

    private func keyboardLayoutGuideCoverageHeight() -> CGFloat {
        guard let observationView else {
            return 0
        }

        if #available(iOS 15.0, *) {
            let layoutFrame = observationView.keyboardLayoutGuide.layoutFrame
            guard layoutFrame.isEmpty == false else {
                return 0
            }
            return max(0, observationView.bounds.intersection(layoutFrame).height)
        }

        return 0
    }

    private func inputAccessoryOverlapHeight() -> CGFloat {
        guard
            let hostView = resolvedHostViewController()?.view,
            let window = hostView.window,
            let webView,
            let inputViewBoundsInWindow = ViewportSPIBridge.inputViewBoundsInWindow(of: webView)
        else {
            return 0
        }

        let inputViewBoundsInHostView = hostView.convert(inputViewBoundsInWindow, from: window)
        return max(0, hostView.bounds.intersection(inputViewBoundsInHostView).height)
    }

    private func observeKeyboardNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleKeyboardDidChangeFrame(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc
    private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        handleKeyboardNotification(notification, resetFrame: false)
    }

    @objc
    private func handleKeyboardDidChangeFrame(_ notification: Notification) {
        handleKeyboardNotification(notification, resetFrame: false)
    }

    @objc
    private func handleKeyboardWillHide(_ notification: Notification) {
        handleKeyboardNotification(notification, resetFrame: true)
    }

    private func handleKeyboardNotification(_ notification: Notification, resetFrame: Bool) {
        guard let endFrameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        keyboardFrameInScreen = endFrameValue.cgRectValue
        if resetFrame {
            keyboardFrameInScreen = .null
        }
        updateViewport()
    }
}

@MainActor
private final class ViewportObservationView: UIView {
    var onViewportGeometryChanged: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onViewportGeometryChanged?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onViewportGeometryChanged?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportGeometryChanged?()
    }
}

private extension UIEdgeInsets {
    func wk_roundedToPixel(_ screenScale: CGFloat) -> UIEdgeInsets {
        guard screenScale > 0 else {
            return self
        }

        func roundToPixel(_ value: CGFloat) -> CGFloat {
            (value * screenScale).rounded() / screenScale
        }

        return UIEdgeInsets(
            top: roundToPixel(top),
            left: roundToPixel(left),
            bottom: roundToPixel(bottom),
            right: roundToPixel(right)
        )
    }
}

@MainActor
@available(iOS 26.0, *)
private extension ScrollEdgeEffectStyle {
    var uiKitStyle: UIScrollEdgeEffect.Style {
        switch self {
        case .automatic:
            .automatic
        case .hard:
            .hard
        case .soft:
            .soft
        }
    }
}
#endif
