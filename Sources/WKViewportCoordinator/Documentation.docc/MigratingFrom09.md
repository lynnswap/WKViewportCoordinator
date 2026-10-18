# Migrating from v0.9.x

Version 0.10 replaced the v0.9 API. Use these replacements when updating older code:

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

The layout width now excludes horizontal window safe areas, including pages with `viewport-fit=cover`. The coordinator preserves insets set by your app or UIKit when it updates or stops. After calling `invalidate()`, create a new coordinator if you need to start again.
