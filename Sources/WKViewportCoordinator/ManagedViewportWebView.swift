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

    /// The configuration used by the embedded viewport coordinator.
    public var viewportConfiguration = ViewportConfiguration() {
        didSet {
            viewportCoordinator?.configuration = viewportConfiguration
        }
    }

    /// The metrics provider used by the embedded viewport coordinator.
    public var viewportMetricsProvider: any ViewportMetricsSource = ViewportMetricsProvider() {
        didSet {
            viewportCoordinator?.metricsProvider = viewportMetricsProvider
        }
    }

    private var viewportCoordinator: ViewportCoordinator?

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
        viewportCoordinator?.handleWebViewHierarchyDidChange()
    }

    /// Notifies the embedded coordinator that the web view moved to a different window.
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportCoordinator?.handleWebViewHierarchyDidChange()
    }

    /// Notifies the embedded coordinator that the web view safe area changed.
    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        viewportCoordinator?.handleWebViewSafeAreaInsetsDidChange()
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
            webView: self,
            configuration: viewportConfiguration,
            metricsProvider: viewportMetricsProvider
        )
    }
}
#endif
