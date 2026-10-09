#if canImport(UIKit)
import UIKit
import WebKit

/// A web view that coordinates its layout viewport with its UIKit host.
///
/// Configure viewport behavior through ``viewportCoordinator`` and scroll
/// behavior and appearance through the inherited `scrollView` property.
@MainActor
open class ViewportWebView: WKWebView {
    /// The coordinator owned by this web view.
    public var viewportCoordinator: ViewportCoordinator { coordinator }

    private var coordinator: ViewportCoordinator!

    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        coordinator = ViewportCoordinator(webView: self)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        coordinator = ViewportCoordinator(webView: self)
    }

    isolated deinit {
        coordinator?.invalidate()
    }

    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        coordinator?.update()
    }

    open override func didMoveToWindow() {
        super.didMoveToWindow()
        coordinator?.update()
    }

    open override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        coordinator?.update()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        coordinator?.update()
    }
}
#endif
