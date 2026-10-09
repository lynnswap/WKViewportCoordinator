#if canImport(UIKit)
import Combine
import UIKit
import WebKit

struct ViewportSafeAreaMetrics: Equatable {
    var viewport: UIEdgeInsets
    var legacyFallbackBaseline: UIEdgeInsets
}

struct ViewportMetrics: Equatable {
    var safeArea: ViewportSafeAreaMetrics
    var obscuredInsets: UIEdgeInsets
    var keyboardOverlapHeight: CGFloat
    var inputAccessoryOverlapHeight: CGFloat
    var additionalObscuredContentInsets: UIEdgeInsets = .zero

    var finalObscuredInsets: UIEdgeInsets {
        var insets = scrollFallbackObscuredInsets
        insets.bottom = max(insets.bottom, keyboardOverlapHeight, inputAccessoryOverlapHeight)
        return insets
    }

    // WebKit already includes keyboard avoidance in its legacy system inset.
    var scrollFallbackObscuredInsets: UIEdgeInsets {
        obscuredInsets.wk_clampedNonNegative.wk_adding(additionalObscuredContentInsets.wk_clampedNonNegative)
    }
}

/// Geometry is expressed in the web view's coordinates, including when its
/// frame occupies only part of the host view or a container overlays a column.
struct ViewportGeometry {
    var bounds: CGRect
    var windowSafeAreaInsets: UIEdgeInsets
    var safeAreaInsets: UIEdgeInsets
    var navigationBarFrame: CGRect?
    var barFrames: [CGRect]

    func obscuredInsets(includesNavigationBar: Bool) -> UIEdgeInsets {
        var insets = windowSafeAreaInsets.wk_maxPerEdge(with: safeAreaInsets)

        if let navigationBarFrame {
            let overlap = bounds.intersection(navigationBarFrame)
            if !overlap.isEmpty {
                insets.top = max(insets.top, overlap.maxY - bounds.minY)
                if !includesNavigationBar {
                    // Retain any system area above the bar and any additional
                    // container safe area below it; exclude only the bar itself.
                    insets.top = max(windowSafeAreaInsets.top, insets.top - overlap.height)
                }
            }
        }

        // Start at an existing safe-area boundary so adjacent native bars can
        // extend it, including a toolbar stacked above a tab bar. Classify each
        // bar before clipping: a narrow web view must not turn a bottom bar into
        // a side bar, nor may a vertical tab bar consume the viewport's height.
        var previous: UIEdgeInsets
        repeat {
            previous = insets
            for frame in barFrames {
                let overlap = bounds.intersection(frame)
                guard !overlap.isEmpty else { continue }
                if frame.width >= frame.height {
                    if abs(frame.minY - bounds.minY) < abs(bounds.maxY - frame.maxY) {
                        let boundary = bounds.minY + max(insets.top, windowSafeAreaInsets.top)
                        if overlap.minY <= boundary {
                            insets.top = max(insets.top, overlap.maxY - bounds.minY)
                        }
                    } else {
                        let boundary = bounds.maxY - max(insets.bottom, windowSafeAreaInsets.bottom)
                        if overlap.maxY >= boundary {
                            insets.bottom = max(insets.bottom, bounds.maxY - overlap.minY)
                        }
                    }
                } else {
                    if abs(frame.minX - bounds.minX) < abs(bounds.maxX - frame.maxX) {
                        let boundary = bounds.minX + max(insets.left, windowSafeAreaInsets.left)
                        if overlap.minX <= boundary {
                            insets.left = max(insets.left, windowSafeAreaInsets.left, overlap.maxX - bounds.minX)
                        }
                    } else {
                        let boundary = bounds.maxX - max(insets.right, windowSafeAreaInsets.right)
                        if overlap.maxX >= boundary {
                            insets.right = max(insets.right, windowSafeAreaInsets.right, bounds.maxX - overlap.minX)
                        }
                    }
                }
            }
        } while previous != insets
        return insets
    }
}

struct ResolvedViewportMetrics: Equatable {
    let viewportSafeAreaInsets: UIEdgeInsets
    let legacyFallbackSafeAreaInsets: UIEdgeInsets
    let obscuredInsets: UIEdgeInsets
    let unobscuredSafeAreaInsets: UIEdgeInsets
    let contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior
    let contentScrollInsetFallback: UIEdgeInsets

    init(
        state: ViewportMetrics,
        contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior,
        screenScale: CGFloat
    ) {
        viewportSafeAreaInsets = state.safeArea.viewport.wk_roundedToPixel(screenScale)
        legacyFallbackSafeAreaInsets = state.safeArea.legacyFallbackBaseline.wk_roundedToPixel(screenScale)
        obscuredInsets = state.finalObscuredInsets.wk_roundedToPixel(screenScale)
        let scrollFallbackObscuredInsets = state.scrollFallbackObscuredInsets.wk_roundedToPixel(screenScale)
        unobscuredSafeAreaInsets = UIEdgeInsets(
            top: max(0, viewportSafeAreaInsets.top - obscuredInsets.top),
            left: max(0, viewportSafeAreaInsets.left - obscuredInsets.left),
            bottom: max(0, viewportSafeAreaInsets.bottom - obscuredInsets.bottom),
            right: max(0, viewportSafeAreaInsets.right - obscuredInsets.right)
        )
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        let safeAreaInsetContribution: UIEdgeInsets
        if contentInsetAdjustmentBehavior == .never {
            safeAreaInsetContribution = .zero
        } else {
            safeAreaInsetContribution = legacyFallbackSafeAreaInsets
        }
        self.contentScrollInsetFallback = UIEdgeInsets(
            top: max(0, scrollFallbackObscuredInsets.top - safeAreaInsetContribution.top),
            left: max(0, scrollFallbackObscuredInsets.left - safeAreaInsetContribution.left),
            bottom: max(0, scrollFallbackObscuredInsets.bottom - safeAreaInsetContribution.bottom),
            right: max(0, scrollFallbackObscuredInsets.right - safeAreaInsetContribution.right)
        )
    }

    func legacyLayoutViewportSize(in bounds: CGRect) -> CGSize {
        let layoutInsets = legacyScrollSystemContentInset.wk_maxPerEdge(with: obscuredInsets)
        let unobscuredRect = bounds.inset(by: layoutInsets)
        return CGSize(
            width: max(0, unobscuredRect.width),
            height: max(0, unobscuredRect.height)
        )
    }

    private var legacyScrollSystemContentInset: UIEdgeInsets {
        contentScrollInsetFallback.wk_adding(safeAreaInsetContributionForFallback)
    }

    private var safeAreaInsetContributionForFallback: UIEdgeInsets {
        guard contentInsetAdjustmentBehavior != .never else {
            return .zero
        }

        return legacyFallbackSafeAreaInsets
    }
}

struct AppliedViewportState: Equatable {
    let resolvedMetrics: ResolvedViewportMetrics
    let contentScrollInset: UIEdgeInsets?
    let legacyLayoutViewportSize: CGSize?

    static func == (lhs: AppliedViewportState, rhs: AppliedViewportState) -> Bool {
        guard lhs.contentScrollInset == rhs.contentScrollInset else {
            return false
        }

        guard lhs.legacyLayoutViewportSize == rhs.legacyLayoutViewportSize else {
            return false
        }

        return lhs.resolvedMetrics.obscuredInsets == rhs.resolvedMetrics.obscuredInsets
            && lhs.resolvedMetrics.unobscuredSafeAreaInsets == rhs.resolvedMetrics.unobscuredSafeAreaInsets
    }
}

@MainActor
final class ViewportMetricsResolver {
    func makeViewportMetrics(
        in hostViewController: UIViewController,
        webView: WKWebView,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat,
        includesNavigationBar: Bool = true
    ) -> ViewportMetrics {
        let windowSafeAreaInsets: UIEdgeInsets
        if let window = webView.window {
            let safeRect = webView.convert(window.bounds.inset(by: window.safeAreaInsets), from: window)
            windowSafeAreaInsets = UIEdgeInsets(
                top: max(0, safeRect.minY - webView.bounds.minY),
                left: max(0, safeRect.minX - webView.bounds.minX),
                bottom: max(0, webView.bounds.maxY - safeRect.maxY),
                right: max(0, webView.bounds.maxX - safeRect.maxX)
            )
        } else {
            windowSafeAreaInsets = .zero
        }
        let navigationController = hostViewController.navigationController
        let toolbar = navigationController?.isToolbarHidden == false ? navigationController?.toolbar : nil
        let geometry = ViewportGeometry(
            bounds: webView.bounds,
            windowSafeAreaInsets: windowSafeAreaInsets,
            safeAreaInsets: webView.safeAreaInsets,
            navigationBarFrame: visibleFrame(of: navigationController?.navigationBar, in: webView),
            barFrames: [hostViewController.tabBarController?.tabBar, toolbar].compactMap {
                visibleFrame(of: $0, in: webView)
            }
        )
        return ViewportMetrics(
            safeArea: ViewportSafeAreaMetrics(
                viewport: windowSafeAreaInsets,
                legacyFallbackBaseline: webView.safeAreaInsets
            ),
            obscuredInsets: geometry.obscuredInsets(includesNavigationBar: includesNavigationBar),
            keyboardOverlapHeight: keyboardOverlapHeight,
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight
        )
    }

    private func visibleFrame(of view: UIView?, in webView: WKWebView) -> CGRect? {
        guard let view, let window = webView.window, view.window === window else { return nil }
        var ancestor: UIView? = view
        while let current = ancestor {
            guard !current.isHidden, current.alpha > 0 else { return nil }
            ancestor = current.superview
        }
        return webView.convert(view.bounds, from: view)
    }
}

/// Coordinates a `WKWebView` viewport with UIKit safe areas, visible chrome, keyboard, and input accessory geometry.
///
/// With `contentInsetAdjustmentBehavior` set to `.never`, the coordinator supplies
/// a contribution to the scroll view's content insets. UIKit's refresh-control
/// adjustments and client-supplied insets are preserved when that contribution
/// changes or is removed. Use ``additionalObscuredContentInsets`` for native UI
/// that also needs to reduce the web layout viewport.
@MainActor
public final class ViewportCoordinator: NSObject {
    /// The view controller that hosts the web view.
    ///
    /// If this value is `nil`, the coordinator resolves a host from the web view's responder chain or window root.
    public weak var hostViewController: UIViewController? {
        didSet {
            updateViewport(force: true)
        }
    }

    private weak var webView: WKWebView?

    /// Whether a visible navigation bar contributes to the obscured content insets.
    ///
    /// The default is `true`. Set this to `false` when the web content already reserves
    /// space for the navigation bar. Window safe-area, bottom-bar, keyboard, input-accessory,
    /// and additional obscured insets are preserved. Set the scroll view's
    /// `contentInsetAdjustmentBehavior` to `.never` to also exclude UIKit's automatic
    /// navigation-bar adjustment. The coordinator does not change that property.
    public var includesNavigationBar = true {
        didSet {
            update()
        }
    }

    /// Additional obscured content insets contributed by client-managed UI.
    ///
    /// Negative values are treated as zero.
    public var additionalObscuredContentInsets: UIEdgeInsets {
        get {
            storedAdditionalObscuredContentInsets
        }
        set {
            storedAdditionalObscuredContentInsets = newValue.wk_clampedNonNegative
            update()
        }
    }

    private var isInvalidated = false
    private let metricsResolver = ViewportMetricsResolver()
    private var storedAdditionalObscuredContentInsets: UIEdgeInsets = .zero
    private var keyboardFrameInScreen: CGRect = .null
    private var lastAppliedViewportState: AppliedViewportState?
    private var observationView: ViewportObservationView?
    private var lastKnownWindowScreen: UIScreen?
    private weak var observedHostViewController: UIViewController?
    private var webViewStateCancellables: Set<AnyCancellable> = []
#if DEBUG
    @objc dynamic private(set) var appliedViewportUpdateCountForTesting = 0
    private var contentScrollViewRegistrationCount = 0
#endif

#if DEBUG
    var resolvedMetricsForTesting: ResolvedViewportMetrics? {
        lastAppliedViewportState?.resolvedMetrics
    }

    var keyboardFrameInScreenForTesting: CGRect {
        keyboardFrameInScreen
    }

    var hasObservationViewForTesting: Bool {
        observationView != nil
    }

    var contentScrollViewRegistrationCountForTesting: Int {
        contentScrollViewRegistrationCount
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

    /// Creates a viewport coordinator for a web view.
    ///
    /// - Parameters:
    ///   - webView: The web view whose viewport should be coordinated.
    ///   - hostViewController: The view controller that hosts the web view. Pass `nil` to resolve it automatically.
    public init(
        webView: WKWebView,
        hostViewController: UIViewController? = nil
    ) {
        self.hostViewController = hostViewController
        self.webView = webView
        super.init()
        observeKeyboardNotifications()
        observeWebViewStateIfPossible()
        update()
    }

    isolated deinit {
        tearDownViewportCoordination()
    }

    /// Recomputes the viewport after a change to the web view's layout or host.
    ///
    /// Forward layout, hierarchy, and safe-area changes here when using a custom
    /// `WKWebView` subclass. ``ViewportWebView`` forwards these automatically.
    /// Calling this after ``invalidate()`` has no effect.
    public func update() {
        let currentScreen = webView?.window?.screen
        if let currentScreen, let lastKnownWindowScreen, lastKnownWindowScreen !== currentScreen {
            keyboardFrameInScreen = .null
        }
        updateViewport(force: false)
    }

    private func updateViewport(force: Bool) {
        guard !isInvalidated, let webView else {
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

        installObservationViewIfPossible(in: observationContainerView)
        updateObservedHostViewControllerIfNeeded(hostViewController, webView: webView)

        registerContentScrollViewIfNeeded(
            webView.scrollView,
            on: hostViewController
        )

        var effectiveMetrics = metricsResolver.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: keyboardOverlapHeight(in: webView),
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight(in: webView),
            includesNavigationBar: includesNavigationBar
        )
        effectiveMetrics.additionalObscuredContentInsets = additionalObscuredContentInsets.wk_clampedNonNegative

        let screenScale = observationContainerView.window?.screen.scale
            ?? webView.window?.screen.scale
            ?? observationContainerView.traitCollection.displayScale
        lastKnownWindowScreen = observationContainerView.window?.screen ?? webView.window?.screen
        let resolvedMetrics = ResolvedViewportMetrics(
            state: effectiveMetrics,
            contentInsetAdjustmentBehavior: webView.scrollView.contentInsetAdjustmentBehavior,
            screenScale: screenScale
        )
        let contentScrollInset: UIEdgeInsets?
        let legacyLayoutViewportSize: CGSize?
        if #available(iOS 26.0, *) {
            contentScrollInset = resolvedMetrics.contentInsetAdjustmentBehavior == .never
                ? resolvedMetrics.obscuredInsets : nil
            legacyLayoutViewportSize = nil
        } else {
            contentScrollInset = resolvedMetrics.contentScrollInsetFallback
            legacyLayoutViewportSize = resolvedMetrics.legacyLayoutViewportSize(in: webView.bounds)
        }
        let appliedViewportState = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInset: contentScrollInset,
            legacyLayoutViewportSize: legacyLayoutViewportSize
        )
        guard force || appliedViewportState != lastAppliedViewportState else {
            return
        }

        let previousContentScrollInset = lastAppliedViewportState?.contentScrollInset
        lastAppliedViewportState = appliedViewportState
        updateContentInsetContribution(
            from: previousContentScrollInset ?? .zero,
            to: contentScrollInset ?? .zero,
            on: webView.scrollView
        )
        if #available(iOS 26.0, *) {
            webView.obscuredContentInsets = resolvedMetrics.obscuredInsets
            ViewportSPIBridge.apply(
                unobscuredSafeAreaInsets: resolvedMetrics.unobscuredSafeAreaInsets,
                to: webView
            )
        } else {
            ViewportSPIBridge.applyLegacyViewportFallback(
                resolvedMetrics,
                to: webView.scrollView,
                webView: webView
            )
        }
#if DEBUG
        appliedViewportUpdateCountForTesting += 1
#endif
    }

    /// Permanently stops coordination and releases its inset contribution and
    /// WebKit overrides. The scroll view's adjustment behavior is preserved.
    ///
    /// Create a new coordinator to start coordinating this web view again.
    public func invalidate() {
        tearDownViewportCoordination()
    }

    private func tearDownViewportCoordination() {
        guard !isInvalidated else { return }
        isInvalidated = true
        NotificationCenter.default.removeObserver(self)
        webViewStateCancellables.removeAll()
        clearObservationViewIfNeeded()
        if let webView {
            resetAppliedViewportInsets(on: webView)
            clearObservedScrollViewIfNeeded(on: observedHostViewController, webView: webView)
        }
        observedHostViewController = nil
        lastAppliedViewportState = nil
        lastKnownWindowScreen = nil
    }

    private func updateContentInsetContribution(
        from previous: UIEdgeInsets,
        to current: UIEdgeInsets,
        on scrollView: UIScrollView
    ) {
        guard previous != current else { return }
        // UIRefreshControl temporarily changes contentInset. Replacing the
        // entire value here loses that adjustment and corrupts its restoration.
        let insets = scrollView.contentInset
        scrollView.contentInset = UIEdgeInsets(
            top: insets.top + current.top - previous.top,
            left: insets.left + current.left - previous.left,
            bottom: insets.bottom + current.bottom - previous.bottom,
            right: insets.right + current.right - previous.right
        )
    }

    private func registerContentScrollViewIfNeeded(
        _ scrollView: UIScrollView,
        on hostViewController: UIViewController
    ) {
        guard
            hostViewController.contentScrollView(for: .top) !== scrollView
                || hostViewController.contentScrollView(for: .bottom)
                    !== scrollView
        else {
            return
        }

        hostViewController.setContentScrollView(scrollView)
#if DEBUG
        contentScrollViewRegistrationCount += 1
#endif
    }

    private func installObservationViewIfPossible(in hostView: UIView) {
        if observationView?.superview === hostView {
            return
        }

        clearObservationViewIfNeeded()

        let observationView = ViewportObservationView(frame: hostView.bounds)
        self.observationView = observationView
        observationView.onViewportGeometryChanged = { [weak self, weak observationView] in
            guard let self, let observationView, self.observationView === observationView else {
                return
            }
            self.update()
        }
        observationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        observationView.isUserInteractionEnabled = false
        observationView.backgroundColor = .clear
        if #available(iOS 15.0, *) {
            observationView.keyboardLayoutGuide.followsUndockedKeyboard = true
        }
        hostView.addSubview(observationView)
        hostView.sendSubviewToBack(observationView)

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
        clearObservationViewIfNeeded()
    }

    private func clearObservationViewIfNeeded() {
        observationView?.onViewportGeometryChanged = nil
        observationView?.removeFromSuperview()
        observationView = nil
    }

    private func resetAppliedViewportInsets(on webView: WKWebView) {
        guard let lastAppliedViewportState else { return }
        updateContentInsetContribution(
            from: lastAppliedViewportState.contentScrollInset ?? .zero,
            to: .zero,
            on: webView.scrollView
        )
        if #available(iOS 26.0, *) {
            ViewportSPIBridge.resetViewportOverrides(on: webView)
        } else {
            ViewportSPIBridge.resetLegacyViewportFallback(on: webView.scrollView, webView: webView)
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

        webView.scrollView.publisher(for: \.contentInsetAdjustmentBehavior, options: [.new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleObservedWebViewStateChange()
            }
            .store(in: &webViewStateCancellables)
    }

    private func handleObservedWebViewStateChange() {
        updateViewport(force: true)
    }

#if DEBUG
    func handleObservedWebViewStateChangeForTesting() {
        handleObservedWebViewStateChange()
    }
#endif

    private func keyboardOverlapHeight(in hostView: UIView?) -> CGFloat {
        let frameIntersectionHeight: CGFloat
        if
            let hostView,
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

        return max(frameIntersectionHeight, keyboardLayoutGuideCoverageHeight(in: hostView))
    }

    private func keyboardLayoutGuideCoverageHeight(in hostView: UIView?) -> CGFloat {
        guard let observationView, let hostView else {
            return 0
        }

        if #available(iOS 15.0, *) {
            let layoutFrame = observationView.bounds.intersection(observationView.keyboardLayoutGuide.layoutFrame)
            guard layoutFrame.isEmpty == false else {
                return 0
            }
            return max(0, hostView.bounds.intersection(hostView.convert(layoutFrame, from: observationView)).height)
        }

        return 0
    }

    private func inputAccessoryOverlapHeight(in hostView: UIView?) -> CGFloat {
        guard
            let hostView,
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
        update()
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

extension UIEdgeInsets {
    var wk_clampedNonNegative: UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, top),
            left: max(0, left),
            bottom: max(0, bottom),
            right: max(0, right)
        )
    }
}

private extension UIEdgeInsets {
    func wk_adding(_ other: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: top + other.top,
            left: left + other.left,
            bottom: bottom + other.bottom,
            right: right + other.right
        )
    }

    func wk_maxPerEdge(with other: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(top, other.top),
            left: max(left, other.left),
            bottom: max(bottom, other.bottom),
            right: max(right, other.right)
        )
    }

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

#endif
