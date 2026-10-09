# WKViewportCoordinator

Keep a `WKWebView`'s layout viewport inside UIKit safe areas and native navigation, tab, and toolbar geometry. The coordinator also accounts for keyboard and input accessory overlap.

Requires iOS 18.4+ and Swift 6.3+.

> [!WARNING]
> This package uses undocumented WebKit APIs. Validate viewport behavior on the OS versions you support before shipping. Unavailable SPI can leave viewport updates or restoration incomplete.

## Installation

Add [WKViewportCoordinator](https://github.com/lynnswap/WKViewportCoordinator) as a Swift package dependency and link the `WKViewportCoordinator` product.

## Usage

```swift
import UIKit
import WebKit
import WKViewportCoordinator

final class BrowserViewController: UIViewController {
    let webView = ViewportWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
```

`ViewportWebView` owns its coordinator and forwards layout, hierarchy, and safe-area changes. It is open for subclassing. The coordinator finds the hosting view controller through the responder chain; set `webView.viewportCoordinator.hostViewController` when a container needs an explicit host.

Configure viewport behavior on `webView.viewportCoordinator`. Use `additionalObscuredContentInsets` for native UI whose space is not represented by the host's safe area. Set `includesNavigationBar` to `false` when the page already reserves the navigation bar's height. This excludes only the bar and preserves the system area above it. Also set `webView.scrollView.contentInsetAdjustmentBehavior = .never` in that case so UIKit does not add the bar's inset independently.

Configure scroll adjustment and edge effects directly on `webView.scrollView`. With automatic inset adjustment disabled, the coordinator adds its own inset contribution while preserving existing insets, including adjustments made by `UIRefreshControl`. The page's layout viewport excludes the window's safe area on all four edges; the page does not need to add that excluded space again through CSS `env(safe-area-inset-*)`.

## Existing web view subclasses

Retain one coordinator for each web view:

```swift
let coordinator = ViewportCoordinator(
    webView: existingWebView,
    hostViewController: hostViewController
)
```

Call `coordinator.update()` after layout, hierarchy, or safe-area changes. In a custom subclass, forward `layoutSubviews()`, `didMoveToSuperview()`, `didMoveToWindow()`, and `safeAreaInsetsDidChange()` after calling `super`.

Call `invalidate()` when coordination ends. It removes the coordinator's inset contribution, releases its WebKit overrides, and stops observation. Further updates have no effect. Create a new coordinator if the same web view needs coordination again.

## Migration from v0.9.x

This API revision is source-breaking.

| Previous API | Replacement |
| --- | --- |
| `ManagedViewportWebView` | `ViewportWebView` |
| Properties prefixed with `viewport` on the web view | Properties on `webView.viewportCoordinator` |
| `includesNavigationBarInObscuredInsets` | `includesNavigationBar` |
| `init(hostViewController:webView:)` | `init(webView:hostViewController:)` |
| `hostViewDidAppear()`, `webViewHierarchyDidChange()`, `webViewSafeAreaInsetsDidChange()`, `updateViewport()` | `update()` |
| Mutable `webView` on the coordinator | Create a coordinator for the new web view |
| `scrollEdgeEffects` and its configuration types | UIKit's `scrollView.topEdgeEffect` and `bottomEdgeEffect` on iOS 26+ |
| `obscuredContentInsetEdgesAffectedBySafeArea` | Removed; the coordinator supplies explicit viewport insets |
| `bottomBarObscurationBehavior` | Removed; visible bar geometry and keyboard overlap determine the affected edges |

Horizontal window safe areas now reduce the page's layout width, including with `viewport-fit=cover`. Insets from other owners are preserved when coordination changes or ends. An invalidated coordinator cannot be restarted.
