# WKViewportCoordinator

`WKWebView` viewport coordination.

## Overview

- iOS 18+
- Swift 6.2+
- `WKWebView`-based viewport management with keyboard and safe-area coordination

> This package relies on undocumented APIs and runtime behavior, so extra care is needed before using it in App Store-bound projects.

## Usage

```swift
import UIKit
import WebKit
import WKViewportCoordinator

final class BrowserViewController: UIViewController {
    let webView = WKWebView(frame: .zero)
    var viewportCoordinator: ViewportCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        viewportCoordinator = ViewportCoordinator(webView: webView)
    }
}
```

`ManagedViewportWebView` is available when you prefer a `WKWebView` subclass that forwards lifecycle updates automatically.

If you attach `ViewportCoordinator` to your own `WKWebView` subclass, forward the relevant lifecycle hooks:

```swift
final class CustomViewportWebView: WKWebView {
    weak var viewportCoordinator: ViewportCoordinator?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        viewportCoordinator?.handleWebViewHierarchyDidChange()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportCoordinator?.handleWebViewHierarchyDidChange()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        viewportCoordinator?.handleWebViewSafeAreaInsetsDidChange()
    }
}
```

Call `handleViewDidAppear()` from the host view controller when you need an explicit refresh after presentation.
