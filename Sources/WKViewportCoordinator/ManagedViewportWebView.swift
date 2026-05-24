#if canImport(UIKit)
import UIKit
import WebKit

/// A `WKWebView` subclass that installs and forwards lifecycle events to a viewport coordinator.
@MainActor
public final class ManagedViewportWebView: WKWebView {
    /// The view controller that hosts the web view.
    ///
    /// Assign this when the responder chain cannot identify the intended host, or when the web view is managed by
    /// a container view controller.
    public weak var viewportHostViewController: UIViewController? {
        didSet {
            viewportCoordinator?.hostViewController = viewportHostViewController
        }
    }

    /// The safe area edges that should affect obscured content inset calculations.
    public var viewportObscuredContentInsetEdgesAffectedBySafeArea: UIRectEdge = [.top, .bottom] {
        didSet {
            viewportCoordinator?.obscuredContentInsetEdgesAffectedBySafeArea =
                viewportObscuredContentInsetEdgesAffectedBySafeArea
        }
    }

    /// Additional obscured content insets contributed by client-managed UI.
    ///
    /// Negative values are treated as zero.
    public var viewportAdditionalObscuredContentInsets: UIEdgeInsets {
        get {
            storedViewportAdditionalObscuredContentInsets
        }
        set {
            storedViewportAdditionalObscuredContentInsets = newValue.wk_clampedNonNegative
            viewportCoordinator?.additionalObscuredContentInsets = storedViewportAdditionalObscuredContentInsets
        }
    }

    /// The behavior used when combining bottom bars with keyboard and input accessory overlap.
    public var viewportBottomBarObscurationBehavior: ViewportBottomBarObscurationBehavior =
        .includeWhenKeyboardOverlaps
    {
        didSet {
            viewportCoordinator?.bottomBarObscurationBehavior = viewportBottomBarObscurationBehavior
        }
    }

    /// The scroll edge effects applied to the web view's scroll view.
    public var viewportScrollEdgeEffects = ViewportScrollEdgeEffects() {
        didSet {
            viewportCoordinator?.scrollEdgeEffects = viewportScrollEdgeEffects
        }
    }

    private var viewportCoordinator: ViewportCoordinator?
    private var storedViewportAdditionalObscuredContentInsets: UIEdgeInsets = .zero

    /// Creates a managed viewport web view.
    ///
    /// - Parameters:
    ///   - frame: The initial frame for the web view.
    ///   - configuration: The web view configuration.
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        installViewportCoordinator()
    }

    /// Creates a managed viewport web view from an archive.
    ///
    /// - Parameter coder: The coder that contains the archived web view.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        installViewportCoordinator()
    }

    isolated deinit {
        viewportCoordinator?.invalidate()
    }

    /// Notifies the embedded coordinator that the web view hierarchy changed.
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        viewportCoordinator?.webViewHierarchyDidChange()
    }

    /// Notifies the embedded coordinator that the web view moved to a different window.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportCoordinator?.webViewHierarchyDidChange()
    }

    /// Notifies the embedded coordinator that the web view safe area changed.
    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        viewportCoordinator?.webViewSafeAreaInsetsDidChange()
    }

    var activeViewportCoordinatorForTesting: ViewportCoordinator? {
        viewportCoordinator
    }

#if DEBUG
    var resolvedHostViewControllerForTesting: UIViewController? {
        viewportCoordinator?.resolvedHostViewControllerForTesting
    }
#endif

    private func installViewportCoordinator() {
        viewportCoordinator = ViewportCoordinator(
            hostViewController: viewportHostViewController,
            webView: self
        )
        viewportCoordinator?.obscuredContentInsetEdgesAffectedBySafeArea =
            viewportObscuredContentInsetEdgesAffectedBySafeArea
        viewportCoordinator?.additionalObscuredContentInsets = storedViewportAdditionalObscuredContentInsets
        viewportCoordinator?.bottomBarObscurationBehavior = viewportBottomBarObscurationBehavior
        viewportCoordinator?.scrollEdgeEffects = viewportScrollEdgeEffects
    }
}
#endif
