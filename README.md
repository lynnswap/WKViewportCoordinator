# WKViewportCoordinator

`WKWebView` viewport coordination.

## Overview

- iOS 18+
- Swift 6.2+
- `WKWebView`-based viewport management with keyboard and safe-area coordination

> [!WARNING]
> This package relies on undocumented APIs and runtime behavior, so extra care is needed before using it in App Store-bound projects.

## Usage

```swift
import UIKit
import WebKit
import WKViewportCoordinator

final class BrowserViewController: UIViewController {
    let webView = ManagedViewportWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        webView.viewportHostViewController = self
    }
}
```

`ManagedViewportWebView` is the preferred integration path because it forwards hierarchy and safe-area lifecycle updates automatically.
If you need non-default scroll inset adjustment, configure UIKit directly with `webView.scrollView.contentInsetAdjustmentBehavior`.

If you attach `ViewportCoordinator` to your own `WKWebView` subclass, you must forward the relevant lifecycle hooks:

```swift
final class CustomViewportWebView: WKWebView {
    weak var viewportCoordinator: ViewportCoordinator?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        viewportCoordinator?.webViewHierarchyDidChange()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportCoordinator?.webViewHierarchyDidChange()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        viewportCoordinator?.webViewSafeAreaInsetsDidChange()
    }
}
```

Call `hostViewDidAppear()` from the host view controller when you need an explicit refresh after presentation.

## Migration

### v0.5.0

These notes apply when upgrading from v0.4.x or earlier to v0.5.0.

- `ViewportConfiguration` has been removed and replaced by individual runtime properties on `ViewportCoordinator`.
- On `ManagedViewportWebView`, use `viewportObscuredContentInsetEdgesAffectedBySafeArea`, `viewportAdditionalObscuredContentInsets`, `viewportBottomBarObscurationBehavior`, and `viewportScrollEdgeEffects`.
- Configure `contentInsetAdjustmentBehavior` directly with `webView.scrollView.contentInsetAdjustmentBehavior`.
- Public metrics/provider APIs have been removed. Custom metrics injection is not provided in `v0.5.0`.
- Removed APIs do not have compatibility shims.
