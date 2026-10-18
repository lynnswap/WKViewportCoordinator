# Adding a web view

Set up automatic viewport updates or attach a coordinator to an existing web view.

## Use ViewportWebView

Add ``ViewportWebView`` to your view controller as you would a `WKWebView`:

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

The web view finds its hosting controller automatically and updates when its layout or safe area changes. Use ``ViewportWebView/viewportCoordinator`` to configure the layout, and the inherited `scrollView` property to configure scrolling and scroll-edge effects.

## Use an existing WKWebView subclass

Create a ``ViewportCoordinator`` and retain it for as long as the web view needs viewport updates. Pass its hosting view controller if automatic lookup does not find the intended host:

```swift
let coordinator = ViewportCoordinator(
    webView: webView,
    hostViewController: hostViewController
)
```

In your web view subclass, call ``ViewportCoordinator/update()`` after `super` in these callbacks:

- `layoutSubviews()`
- `didMoveToSuperview()`
- `didMoveToWindow()`
- `safeAreaInsetsDidChange()`

Call ``ViewportCoordinator/invalidate()`` when you no longer want the coordinator to adjust the page. It removes its adjustments and stops observing changes. Create a new coordinator to start again.

## Compatibility

The package uses undocumented WebKit APIs. If a required API is unavailable, viewport adjustment or reset may be incomplete.
