#if canImport(UIKit)
import Combine
import UIKit
import WebKit

/// Controls how bottom bars contribute to the final obscured viewport inset.
public enum ViewportBottomBarObscurationBehavior: Equatable {
    /// Includes bottom bars while keyboard or input accessory overlap is active.
    case includeWhenKeyboardOverlaps

    /// Ignores bottom bars while keyboard or input accessory overlap is active.
    case ignoreWhenKeyboardOrAccessoryOverlaps
}

/// Scroll edge effects applied to a coordinated web view's scroll view.
public struct ViewportScrollEdgeEffects: Equatable {
    /// The top scroll edge effect.
    public var top: ViewportScrollEdgeEffect

    /// The bottom scroll edge effect.
    public var bottom: ViewportScrollEdgeEffect

    /// Creates scroll edge effects.
    ///
    /// - Parameters:
    ///   - top: The top scroll edge effect.
    ///   - bottom: The bottom scroll edge effect.
    public init(
        top: ViewportScrollEdgeEffect = ViewportScrollEdgeEffect(),
        bottom: ViewportScrollEdgeEffect = ViewportScrollEdgeEffect()
    ) {
        self.top = top
        self.bottom = bottom
    }
}

/// A scroll edge effect applied to one edge of a coordinated web view's scroll view.
public struct ViewportScrollEdgeEffect: Equatable {
    /// Describes the scroll edge effect style.
    public enum Style: Equatable {
        /// Uses UIKit's automatic edge effect style.
        case automatic

        /// Uses a hard edge effect style.
        case hard

        /// Uses a soft edge effect style.
        case soft
    }

    /// A Boolean value indicating whether the edge effect is hidden.
    public var isHidden: Bool

    /// The style applied to the edge effect.
    public var style: Style

    /// Creates a scroll edge effect.
    ///
    /// - Parameters:
    ///   - isHidden: Whether the edge effect should be hidden.
    ///   - style: The style applied to the edge effect.
    public init(isHidden: Bool = false, style: Style = .soft) {
        self.isHidden = isHidden
        self.style = style
    }
}

struct ViewportSafeAreaMetrics: Equatable {
    var viewport: UIEdgeInsets
    var legacyFallbackBaseline: UIEdgeInsets

    init(
        viewport: UIEdgeInsets,
        legacyFallbackBaseline: UIEdgeInsets
    ) {
        self.viewport = viewport
        self.legacyFallbackBaseline = legacyFallbackBaseline
    }
}

struct ViewportMetrics: Equatable {
    var safeArea: ViewportSafeAreaMetrics
    var topObscuredHeight: CGFloat
    var bottomObscuredHeight: CGFloat
    var keyboardOverlapHeight: CGFloat
    var inputAccessoryOverlapHeight: CGFloat
    var bottomBarObscurationBehavior: ViewportBottomBarObscurationBehavior
    var additionalObscuredContentInsets: UIEdgeInsets
    var obscuredContentInsetEdgesAffectedBySafeArea: UIRectEdge

    init(
        safeArea: ViewportSafeAreaMetrics,
        topObscuredHeight: CGFloat,
        bottomObscuredHeight: CGFloat,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat,
        bottomBarObscurationBehavior: ViewportBottomBarObscurationBehavior = .includeWhenKeyboardOverlaps,
        additionalObscuredContentInsets: UIEdgeInsets = .zero,
        obscuredContentInsetEdgesAffectedBySafeArea: UIRectEdge = [.top, .bottom]
    ) {
        self.safeArea = safeArea
        self.topObscuredHeight = topObscuredHeight
        self.bottomObscuredHeight = bottomObscuredHeight
        self.keyboardOverlapHeight = keyboardOverlapHeight
        self.inputAccessoryOverlapHeight = inputAccessoryOverlapHeight
        self.bottomBarObscurationBehavior = bottomBarObscurationBehavior
        self.additionalObscuredContentInsets = additionalObscuredContentInsets.wk_clampedNonNegative
        self.obscuredContentInsetEdgesAffectedBySafeArea = obscuredContentInsetEdgesAffectedBySafeArea
    }

    var finalObscuredInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, topObscuredHeight) + additionalObscuredContentInsets.top,
            left: additionalObscuredContentInsets.left,
            bottom: resolvedBottomObscuredHeight,
            right: additionalObscuredContentInsets.right
        )
    }

    var scrollFallbackObscuredInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, topObscuredHeight) + additionalObscuredContentInsets.top,
            left: additionalObscuredContentInsets.left,
            bottom: resolvedBottomScrollFallbackHeight,
            right: additionalObscuredContentInsets.right
        )
    }

    private var resolvedBottomObscuredHeight: CGFloat {
        let chromeHeight = resolvedBottomChromeHeight
        let keyboardHeight = max(0, keyboardOverlapHeight)
        let accessoryHeight = max(0, inputAccessoryOverlapHeight)
        switch bottomBarObscurationBehavior {
        case .includeWhenKeyboardOverlaps:
            return max(0, chromeHeight, keyboardHeight, accessoryHeight)
        case .ignoreWhenKeyboardOrAccessoryOverlaps:
            if keyboardHeight > 0 || accessoryHeight > 0 {
                return max(keyboardHeight, accessoryHeight)
            }
            return chromeHeight
        }
    }

    private var resolvedBottomChromeHeight: CGFloat {
        max(0, bottomObscuredHeight) + additionalObscuredContentInsets.bottom
    }

    private var resolvedBottomScrollFallbackHeight: CGFloat {
        switch bottomBarObscurationBehavior {
        case .includeWhenKeyboardOverlaps:
            return resolvedBottomChromeHeight
        case .ignoreWhenKeyboardOrAccessoryOverlaps:
            if max(0, keyboardOverlapHeight) > 0 || max(0, inputAccessoryOverlapHeight) > 0 {
                return 0
            }
            return resolvedBottomChromeHeight
        }
    }
}

struct ResolvedViewportMetrics: Equatable {
    let viewportSafeAreaInsets: UIEdgeInsets
    let legacyFallbackSafeAreaInsets: UIEdgeInsets
    let obscuredInsets: UIEdgeInsets
    let unobscuredSafeAreaInsets: UIEdgeInsets
    let obscuredContentInsetEdgesAffectedBySafeArea: UIRectEdge
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
        obscuredContentInsetEdgesAffectedBySafeArea = state.obscuredContentInsetEdgesAffectedBySafeArea
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        let safeAreaInsetContribution: UIEdgeInsets
        if contentInsetAdjustmentBehavior == .never {
            safeAreaInsetContribution = .zero
        } else {
            safeAreaInsetContribution = UIEdgeInsets(
                top: obscuredContentInsetEdgesAffectedBySafeArea.contains(.top) ? legacyFallbackSafeAreaInsets.top : 0,
                left: obscuredContentInsetEdgesAffectedBySafeArea.contains(.left) ? legacyFallbackSafeAreaInsets.left : 0,
                bottom: obscuredContentInsetEdgesAffectedBySafeArea.contains(.bottom) ? legacyFallbackSafeAreaInsets.bottom : 0,
                right: obscuredContentInsetEdgesAffectedBySafeArea.contains(.right) ? legacyFallbackSafeAreaInsets.right : 0
            )
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

        return UIEdgeInsets(
            top: obscuredContentInsetEdgesAffectedBySafeArea.contains(.top) ? legacyFallbackSafeAreaInsets.top : 0,
            left: obscuredContentInsetEdgesAffectedBySafeArea.contains(.left) ? legacyFallbackSafeAreaInsets.left : 0,
            bottom: obscuredContentInsetEdgesAffectedBySafeArea.contains(.bottom) ? legacyFallbackSafeAreaInsets.bottom : 0,
            right: obscuredContentInsetEdgesAffectedBySafeArea.contains(.right) ? legacyFallbackSafeAreaInsets.right : 0
        )
    }
}

struct AppliedViewportState: Equatable {
    let resolvedMetrics: ResolvedViewportMetrics
    let contentScrollInsetFallback: UIEdgeInsets?
    let legacyLayoutViewportSize: CGSize?

    static func == (lhs: AppliedViewportState, rhs: AppliedViewportState) -> Bool {
        guard lhs.contentScrollInsetFallback == rhs.contentScrollInsetFallback else {
            return false
        }

        guard lhs.legacyLayoutViewportSize == rhs.legacyLayoutViewportSize else {
            return false
        }

        return lhs.resolvedMetrics.obscuredInsets == rhs.resolvedMetrics.obscuredInsets
            && lhs.resolvedMetrics.unobscuredSafeAreaInsets == rhs.resolvedMetrics.unobscuredSafeAreaInsets
            && lhs.resolvedMetrics.obscuredContentInsetEdgesAffectedBySafeArea
                == rhs.resolvedMetrics.obscuredContentInsetEdgesAffectedBySafeArea
    }
}

@MainActor
final class ViewportMetricsResolver {
    func makeViewportMetrics(
        in hostViewController: UIViewController,
        webView: WKWebView,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat
    ) -> ViewportMetrics {
        let hostView = webView.superview ?? hostViewController.viewIfLoaded
        let viewportSafeAreaInsets = projectedWindowSafeAreaInsets(in: hostView)
        let legacyFallbackSafeAreaInsets = hostView?.safeAreaInsets ?? .zero
        let topObscuredHeight = max(
            viewportSafeAreaInsets.top,
            topEdgeObscuredHeight(
                of: hostViewController.navigationController?.navigationBar,
                in: hostView,
                extendingFrom: viewportSafeAreaInsets.top
            )
        )
        let bottomObscuredHeight = bottomEdgeObscuredHeight(
            of: [
                hostViewController.tabBarController?.tabBar,
                resolvedVisibleToolbar(for: hostViewController),
            ],
            in: hostView,
            extendingFrom: viewportSafeAreaInsets.bottom
        )
        return ViewportMetrics(
            safeArea: ViewportSafeAreaMetrics(
                viewport: viewportSafeAreaInsets,
                legacyFallbackBaseline: legacyFallbackSafeAreaInsets
            ),
            topObscuredHeight: topObscuredHeight,
            bottomObscuredHeight: bottomObscuredHeight,
            keyboardOverlapHeight: keyboardOverlapHeight,
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight
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

    private func bottomEdgeObscuredHeight(of chromeView: UIView?, in hostView: UIView?) -> CGFloat {
        bottomEdgeObscuredHeight(of: [chromeView], in: hostView)
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
}

/// Coordinates a `WKWebView` viewport with UIKit safe areas, visible chrome, keyboard, and input accessory geometry.
@MainActor
public final class ViewportCoordinator: NSObject {
    /// The view controller that hosts the web view.
    ///
    /// If this value is `nil`, the coordinator resolves a host from the web view's responder chain or window root.
    public weak var hostViewController: UIViewController? {
        didSet {
            lastAppliedViewportState = nil
            updateViewport()
        }
    }

    /// The web view whose viewport is coordinated.
    public weak var webView: WKWebView?

    /// The safe area edges that should affect obscured content inset calculations.
    public var obscuredContentInsetEdgesAffectedBySafeArea: UIRectEdge = [.top, .bottom] {
        didSet {
            updateViewport()
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
            updateViewport()
        }
    }

    /// The behavior used when combining bottom bars with keyboard and input accessory overlap.
    public var bottomBarObscurationBehavior: ViewportBottomBarObscurationBehavior = .includeWhenKeyboardOverlaps {
        didSet {
            updateViewport()
        }
    }

    /// The scroll edge effects applied to the web view's scroll view.
    public var scrollEdgeEffects = ViewportScrollEdgeEffects() {
        didSet {
            updateViewport()
        }
    }

    private let metricsResolver = ViewportMetricsResolver()
    private var storedAdditionalObscuredContentInsets: UIEdgeInsets = .zero
    private var keyboardFrameInScreen: CGRect = .null
    private var lastAppliedViewportState: AppliedViewportState?
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
        lastAppliedViewportState?.resolvedMetrics
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

    /// Creates a viewport coordinator for a web view.
    ///
    /// - Parameters:
    ///   - hostViewController: The view controller that hosts the web view. Pass `nil` to resolve it automatically.
    ///   - webView: The web view whose viewport should be coordinated.
    public init(
        hostViewController: UIViewController? = nil,
        webView: WKWebView
    ) {
        self.hostViewController = hostViewController
        self.webView = webView
        super.init()
        observeKeyboardNotifications()
        observeWebViewStateIfPossible()
        updateViewport()
    }

    /// Creates a viewport coordinator that resolves its host view controller automatically.
    ///
    /// - Parameter webView: The web view whose viewport should be coordinated.
    public convenience init(webView: WKWebView) {
        self.init(
            hostViewController: nil,
            webView: webView
        )
    }

    isolated deinit {
        tearDownViewportCoordination(resetViewport: true)
    }

    /// Refreshes viewport state after the host view controller appears.
    public func hostViewDidAppear() {
        updateViewport()
    }

    /// Refreshes viewport state after the web view moves between superviews, windows, or screens.
    public func webViewHierarchyDidChange() {
        let currentScreen = webView?.window?.screen
        if let currentScreen, let lastKnownWindowScreen, lastKnownWindowScreen !== currentScreen {
            keyboardFrameInScreen = .null
        }
        if let currentScreen {
            lastKnownWindowScreen = currentScreen
        }
        updateViewport()
    }

    /// Refreshes viewport state after the web view's safe area insets change.
    public func webViewSafeAreaInsetsDidChange() {
        lastAppliedViewportState = nil
        updateViewport()
    }

    /// Recomputes and applies the current viewport state.
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

        applyScrollEdgeEffects(to: webView.scrollView)
        hostViewController.setContentScrollView(webView.scrollView)

        let metricsHostView = resolvedMetricsHostView(webView: webView, hostViewController: hostViewController)
        var effectiveMetrics = metricsResolver.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: keyboardOverlapHeight(in: metricsHostView),
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight(in: metricsHostView)
        )
        effectiveMetrics.obscuredContentInsetEdgesAffectedBySafeArea = obscuredContentInsetEdgesAffectedBySafeArea
        effectiveMetrics.additionalObscuredContentInsets = additionalObscuredContentInsets.wk_clampedNonNegative
        effectiveMetrics.bottomBarObscurationBehavior = bottomBarObscurationBehavior

        let screenScale = observationContainerView.window?.screen.scale
            ?? webView.window?.screen.scale
            ?? observationContainerView.traitCollection.displayScale
        lastKnownWindowScreen = observationContainerView.window?.screen ?? webView.window?.screen
        let resolvedMetrics = ResolvedViewportMetrics(
            state: effectiveMetrics,
            contentInsetAdjustmentBehavior: webView.scrollView.contentInsetAdjustmentBehavior,
            screenScale: screenScale
        )
        let contentScrollInsetFallback: UIEdgeInsets?
        let legacyLayoutViewportSize: CGSize?
        if #available(iOS 26.0, *) {
            contentScrollInsetFallback = nil
            legacyLayoutViewportSize = nil
        } else {
            contentScrollInsetFallback = resolvedMetrics.contentScrollInsetFallback
            legacyLayoutViewportSize = resolvedMetrics.legacyLayoutViewportSize(in: webView.bounds)
        }
        let appliedViewportState = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInsetFallback: contentScrollInsetFallback,
            legacyLayoutViewportSize: legacyLayoutViewportSize
        )
        guard appliedViewportState != lastAppliedViewportState else {
            return
        }

        lastAppliedViewportState = appliedViewportState
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
                obscuredSafeAreaEdges: resolvedMetrics.obscuredContentInsetEdgesAffectedBySafeArea,
                to: webView
            )
        } else {
            ViewportSPIBridge.applyLegacyViewportFallback(
                resolvedMetrics,
                to: webView.scrollView,
                webView: webView
            )
        }
    }

    /// Stops observation and resets the viewport state applied to the web view.
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
        lastAppliedViewportState = nil
        lastKnownWindowScreen = nil
    }

    private func applyScrollEdgeEffects(to scrollView: UIScrollView) {
        if #available(iOS 26.0, *) {
            scrollView.topEdgeEffect.isHidden = scrollEdgeEffects.top.isHidden
            scrollView.topEdgeEffect.style = scrollEdgeEffects.top.style.uiKitStyle
            scrollView.bottomEdgeEffect.isHidden = scrollEdgeEffects.bottom.isHidden
            scrollView.bottomEdgeEffect.style = scrollEdgeEffects.bottom.style.uiKitStyle
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

    private func resolvedMetricsHostView(webView: WKWebView, hostViewController: UIViewController) -> UIView? {
        webView.superview ?? hostViewController.viewIfLoaded
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
        lastAppliedViewportState = nil
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
            _ = ViewportSPIBridge.resetLegacyViewportFallback(
                on: webView.scrollView,
                webView: webView
            )
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
        lastAppliedViewportState = nil
        updateViewport()
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

@MainActor
@available(iOS 26.0, *)
private extension ViewportScrollEdgeEffect.Style {
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
