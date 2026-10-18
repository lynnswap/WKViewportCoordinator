# WKViewportCoordinator

Adjust a `WKWebView`'s page layout for UIKit safe areas, native bars, and the keyboard. The web view keeps its full frame.

## Requirements

- iOS 18.4+
- Swift 6.3+

In Xcode, add `https://github.com/lynnswap/WKViewportCoordinator` as a package dependency and select the `WKViewportCoordinator` product.

## Quick start

### Update the viewport automatically

Use `ViewportWebView` in place of `WKWebView`:

```swift
import UIKit
import WebKit
import WKViewportCoordinator

final class BrowserViewController: UIViewController {
    let webView = ViewportWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override func loadView() {
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: URL(string: "https://example.com")!))
    }
}
```

The web view finds its hosting controller and updates the page as UIKit's layout changes. The default settings handle safe-area spacing; you don't need to add it again in CSS.

### Use your existing WKWebView subclass

Create and retain a coordinator for your `WKWebView` subclass:

```swift
let coordinator = ViewportCoordinator(
    webView: webView,
    hostViewController: hostViewController
)
```

Call `update()` from the web view's layout, hierarchy, and safe-area callbacks. Call `invalidate()` when you want to stop coordination. See [Adding a web view](https://lynnswap.github.io/WKViewportCoordinator/documentation/wkviewportcoordinator/addingawebview) for the callbacks and lifetime rules.

## Documentation

The [DocC guides and API reference](https://lynnswap.github.io/WKViewportCoordinator/documentation/wkviewportcoordinator/) cover:

- [Adding a web view](https://lynnswap.github.io/WKViewportCoordinator/documentation/wkviewportcoordinator/addingawebview)
- [Configuring the layout](https://lynnswap.github.io/WKViewportCoordinator/documentation/wkviewportcoordinator/configuringthelayout), including custom overlays and drawing behind native bars
- [Migrating from v0.9.x](https://lynnswap.github.io/WKViewportCoordinator/documentation/wkviewportcoordinator/migratingfrom09)

The package uses undocumented WebKit APIs internally. See the compatibility notes in [Adding a web view](https://lynnswap.github.io/WKViewportCoordinator/documentation/wkviewportcoordinator/addingawebview).
