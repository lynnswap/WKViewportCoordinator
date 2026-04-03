# WKViewportCoordinator

`WKWebView` viewport coordination for iOS.

## Overview

- iOS 18+
- Swift 6.2+
- `WKWebView`-based viewport management with keyboard and safe-area coordination
- Private WebKit/UIKit selectors are used internally

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

## Notes

- The module name is `WKViewportCoordinator`.
- Public type names are unchanged from the former `WKViewport` target.
- This package is intentionally standalone and does not depend on `WebInspectorKit`.
