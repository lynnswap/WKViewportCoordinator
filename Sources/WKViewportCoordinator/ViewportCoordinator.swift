#if canImport(UIKit)
import ABIBridge
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
    var additionalScrollContentInsets: UIEdgeInsets = .zero

    var finalObscuredInsets: UIEdgeInsets {
        var insets = baseObscuredInsets
        insets.bottom = max(insets.bottom, keyboardOverlapHeight, inputAccessoryOverlapHeight)
        return insets
    }

    var finalScrollContentInsets: UIEdgeInsets {
        var insets = scrollFallbackObscuredInsets
        insets.bottom = max(insets.bottom, keyboardOverlapHeight, inputAccessoryOverlapHeight)
        return insets
    }

    // WebKit already includes keyboard avoidance in its legacy system inset.
    var scrollFallbackObscuredInsets: UIEdgeInsets {
        baseObscuredInsets.wk_adding(additionalScrollContentInsets)
    }

    private var baseObscuredInsets: UIEdgeInsets {
        obscuredInsets.wk_adding(additionalObscuredContentInsets)
    }

    /// Extends a horizontal inset so that WebKit does not round the unobscured width up.
    ///
    /// WebKit lays out a `width=device-width` page at the whole number of points nearest
    /// to the unobscured width. Rounded up, the page is wider than the area that shows
    /// it, and scrolls sideways.
    mutating func keepPageWidthWithinUnobscuredWidth(of bounds: CGRect, screenScale: CGFloat) {
        guard screenScale > 0 else { return }
        let insets = finalObscuredInsets.wk_roundedToPixel(screenScale)
        let width = bounds.width - insets.left - insets.right
        // WebKit rounds the width in single precision.
        guard width > 0, Float(width).rounded() > Float(width) else { return }
        // The resolved insets are rounded to pixels, so extend by whole pixels. Rounding
        // down leaves the width less than a pixel above a whole point, which WebKit rounds down.
        let pixels = ((width - width.rounded(.down)) * screenScale + 0.001).rounded(.down)
        if insets.left > insets.right {
            obscuredInsets.left += pixels / screenScale
        } else {
            obscuredInsets.right += pixels / screenScale
        }
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

    /// The window's safe area that the page has to keep clear. A navigation bar
    /// can lie inside the window's top band, as it does beside the system
    /// controls of an unfolded iPhone. A page that reserves the bar's space
    /// itself then keeps clear of the band above the bar only.
    func viewportSafeAreaInsets(includesNavigationBar: Bool) -> UIEdgeInsets {
        var insets = windowSafeAreaInsets
        if !includesNavigationBar, let navigationBarFrame {
            let overlap = bounds.intersection(navigationBarFrame)
            if !overlap.isEmpty {
                insets.top = min(insets.top, overlap.minY - bounds.minY)
            }
        }
        return insets
    }

    func obscuredInsets(includesNavigationBar: Bool) -> UIEdgeInsets {
        let windowSafeAreaInsets = viewportSafeAreaInsets(includesNavigationBar: includesNavigationBar)
        var insets = self.windowSafeAreaInsets.wk_maxPerEdge(with: safeAreaInsets)

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
    let contentScrollInsets: UIEdgeInsets

    init(
        state: ViewportMetrics,
        contentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior,
        screenScale: CGFloat
    ) {
        viewportSafeAreaInsets = state.safeArea.viewport.wk_roundedToPixel(screenScale)
        legacyFallbackSafeAreaInsets = state.safeArea.legacyFallbackBaseline.wk_roundedToPixel(screenScale)
        obscuredInsets = state.finalObscuredInsets.wk_roundedToPixel(screenScale)
        contentScrollInsets = state.finalScrollContentInsets.wk_roundedToPixel(screenScale)
        let scrollFallbackObscuredInsets = state.scrollFallbackObscuredInsets.wk_roundedToPixel(screenScale)
        // Insets excluded from the layout viewport still protect fixed controls through CSS env().
        let safeAreaInsets = viewportSafeAreaInsets.wk_maxPerEdge(
            with: state.additionalScrollContentInsets.wk_roundedToPixel(screenScale)
        )
        unobscuredSafeAreaInsets = UIEdgeInsets(
            top: max(0, safeAreaInsets.top - obscuredInsets.top),
            left: max(0, safeAreaInsets.left - obscuredInsets.left),
            bottom: max(0, safeAreaInsets.bottom - obscuredInsets.bottom),
            right: max(0, safeAreaInsets.right - obscuredInsets.right)
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
        includesNavigationBar: Bool = true,
        obscuredContentInsetEdges: UIRectEdge = .all
    ) -> ViewportMetrics {
        let windowSafeAreaInsets: UIEdgeInsets
        if let window = webView.window {
            let windowRect = webView.convert(window.bounds, from: window)
            let safeRect = webView.convert(window.bounds.inset(by: window.safeAreaInsets), from: window)
            windowSafeAreaInsets = Self.windowSafeAreaInsets(
                in: webView.bounds, windowBounds: windowRect, safeArea: safeRect
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
        let scrollObscuredInsets = geometry.obscuredInsets(includesNavigationBar: includesNavigationBar)
        let obscuredInsets = UIEdgeInsets(
            top: obscuredContentInsetEdges.contains(.top) ? scrollObscuredInsets.top : 0,
            left: obscuredContentInsetEdges.contains(.left) ? scrollObscuredInsets.left : 0,
            bottom: obscuredContentInsetEdges.contains(.bottom) ? scrollObscuredInsets.bottom : 0,
            right: obscuredContentInsetEdges.contains(.right) ? scrollObscuredInsets.right : 0
        )
        return ViewportMetrics(
            safeArea: ViewportSafeAreaMetrics(
                viewport: geometry.viewportSafeAreaInsets(includesNavigationBar: includesNavigationBar),
                legacyFallbackBaseline: webView.safeAreaInsets
            ),
            obscuredInsets: obscuredInsets,
            keyboardOverlapHeight: keyboardOverlapHeight,
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight,
            additionalScrollContentInsets: scrollObscuredInsets.wk_subtractingClamped(obscuredInsets)
        )
    }

    // Only the window's unsafe bands obscure content. A host moving outside
    // the window changes clipping, not the page's layout viewport.
    static func windowSafeAreaInsets(in bounds: CGRect, windowBounds: CGRect, safeArea: CGRect) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, min(bounds.maxY, safeArea.minY) - max(bounds.minY, windowBounds.minY)),
            left: max(0, min(bounds.maxX, safeArea.minX) - max(bounds.minX, windowBounds.minX)),
            bottom: max(0, min(bounds.maxY, windowBounds.maxY) - max(bounds.minY, safeArea.maxY)),
            right: max(0, min(bounds.maxX, windowBounds.maxX) - max(bounds.minX, safeArea.maxX))
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

/// Adjusts a web page's layout for safe areas, native bars, and the keyboard.
///
/// Use ``ViewportWebView`` for automatic updates. For another `WKWebView`
/// subclass, retain a coordinator and call ``update()`` after layout, hierarchy,
/// and safe-area changes.
@MainActor
public final class ViewportCoordinator: NSObject {
    /// The view controller that hosts the web view.
    ///
    /// When `nil`, the coordinator finds the host through the web view's responder
    /// chain or the window's root view controller.
    public weak var hostViewController: UIViewController? {
        didSet {
            updateViewport(force: true)
        }
    }

    private weak var webView: WKWebView?

    /// Whether the page's layout leaves room for a visible navigation bar.
    ///
    /// Defaults to `true`. Set this to `false` when the page already reserves that
    /// space, and set the scroll view's `contentInsetAdjustmentBehavior` to `.never`
    /// so UIKit does not add the bar's inset independently. The safe area above the
    /// bar and all other obscured insets still apply.
    public var includesNavigationBar = true {
        didSet {
            update()
        }
    }

    /// The edges where UIKit insets reduce the page's layout area.
    ///
    /// Defaults to `.all`. Exclude an edge to draw beneath its safe area and native
    /// bars. Content can still scroll clear of them; fixed controls must use CSS
    /// `env(safe-area-inset-*)` to avoid them.
    ///
    /// Keyboard and input accessory avoidance, and ``additionalObscuredContentInsets``,
    /// apply regardless of this setting.
    @available(iOS 26.0, *)
    public var obscuredContentInsetEdges: UIRectEdge {
        get { storedObscuredContentInsetEdges }
        set {
            storedObscuredContentInsetEdges = newValue
            update()
        }
    }

    /// Extra space for overlays not included in the host's safe area.
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
    private var storedObscuredContentInsetEdges: UIRectEdge = .all
    private var keyboardFrameInScreen: CGRect = .null
    private var lastAppliedViewportState: AppliedViewportState?
    private var defaultViewportSizeCoordination: [NativeObjCMethodHook] = []
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
        if #available(iOS 26.0, *) {
            defaultViewportSizeCoordination = ViewportSPIBridge.coordinateDefaultViewportSize(in: webView) { [weak self] in
                guard let self else { return false }
                return !isInvalidated && lastAppliedViewportState != nil
            }
        }
        observeKeyboardNotifications()
        observeWebViewStateIfPossible()
        update()
    }

    isolated deinit {
        tearDownViewportCoordination()
    }

    /// Updates the page's layout to match the current UIKit layout.
    ///
    /// Forward layout, hierarchy, and safe-area changes here when using a custom
    /// `WKWebView` subclass. ``ViewportWebView`` forwards these automatically.
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
            let window = observationContainerView.window
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
            hostViewController.viewIfLoaded?.window != nil
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
            includesNavigationBar: includesNavigationBar,
            obscuredContentInsetEdges: storedObscuredContentInsetEdges
        )
        effectiveMetrics.additionalObscuredContentInsets = additionalObscuredContentInsets
        effectiveMetrics.keepPageWidthWithinUnobscuredWidth(of: webView.bounds, screenScale: window.screen.scale)

        lastKnownWindowScreen = window.screen
        let resolvedMetrics = ResolvedViewportMetrics(
            state: effectiveMetrics,
            contentInsetAdjustmentBehavior: webView.scrollView.contentInsetAdjustmentBehavior,
            screenScale: window.screen.scale
        )
        let contentScrollInset: UIEdgeInsets?
        let legacyLayoutViewportSize: CGSize?
        if #available(iOS 26.0, *) {
            contentScrollInset = resolvedMetrics.contentInsetAdjustmentBehavior == .never
                ? resolvedMetrics.contentScrollInsets : nil
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
            ViewportSPIBridge.applyDefaultViewportSize(to: webView)
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

    /// Stops automatic updates and removes this coordinator's adjustments.
    ///
    /// The scroll view's `contentInsetAdjustmentBehavior` is unchanged.
    /// Calling ``update()`` after this has no effect; create a new coordinator to start again.
    public func invalidate() {
        tearDownViewportCoordination()
    }

    private func tearDownViewportCoordination() {
        guard !isInvalidated else { return }
        isInvalidated = true
        defaultViewportSizeCoordination.forEach { $0.invalidate() }
        defaultViewportSizeCoordination.removeAll()
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
        observationView.keyboardLayoutGuide.followsUndockedKeyboard = true
        // A hidden keyboard must not reintroduce native chrome as keyboard overlap.
        observationView.keyboardLayoutGuide.usesBottomSafeArea = false
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
            // Flag resets do not recalculate WebKit's layout viewport.
            webView.obscuredContentInsets = .zero
            ViewportSPIBridge.resetViewportOverrides(on: webView)
            ViewportSPIBridge.restoreDefaultViewportSize(on: webView)
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

        let layoutFrame = observationView.bounds.intersection(observationView.keyboardLayoutGuide.layoutFrame)
        guard layoutFrame.isEmpty == false else {
            return 0
        }
        return max(0, hostView.bounds.intersection(hostView.convert(layoutFrame, from: observationView)).height)
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
        for name in [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardDidChangeFrameNotification] {
            center.addObserver(self, selector: #selector(handleKeyboardFrameChange(_:)), name: name, object: nil)
        }
        center.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc
    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }
        keyboardFrameInScreen = endFrame.cgRectValue
        update()
    }

    @objc
    private func handleKeyboardWillHide() {
        keyboardFrameInScreen = .null
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

private extension UIEdgeInsets {
    var wk_clampedNonNegative: UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, top),
            left: max(0, left),
            bottom: max(0, bottom),
            right: max(0, right)
        )
    }

    func wk_subtractingClamped(_ other: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, top - other.top),
            left: max(0, left - other.left),
            bottom: max(0, bottom - other.bottom),
            right: max(0, right - other.right)
        )
    }

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
