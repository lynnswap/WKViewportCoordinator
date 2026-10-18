# Configuring the layout

Reserve space for native UI or let the page draw behind it.

## Use the default layout

By default, the page's layout avoids native UI on all four edges. The page does not need to add CSS safe-area padding for that excluded space.

Fixed elements follow the adjusted layout edges, and `100vw` matches the layout width. WebKit still determines height-based units such as `vh` and the small and large viewport units.

## Use a page that already reserves navigation-bar space

If your page already leaves room for the native navigation bar, exclude that bar from the coordinator's calculation:

```swift
webView.viewportCoordinator.includesNavigationBar = false
webView.scrollView.contentInsetAdjustmentBehavior = .never
```

The second line prevents UIKit from adding the navigation-bar inset independently. The safe area above the bar still applies. When automatic inset adjustment is disabled, the coordinator adjusts scroll insets itself and preserves insets set by your app or `UIRefreshControl`.

## Reserve space for custom overlays

Use ``ViewportCoordinator/additionalObscuredContentInsets`` for native UI that is not included in the host's safe area.

For a bottom overlay whose height is not already included in that area:

```swift
webView.viewportCoordinator.additionalObscuredContentInsets.bottom = overlayHeight
```

## Draw behind native bars

On iOS 26 and later, ``ViewportCoordinator/obscuredContentInsetEdges`` lets the page extend beneath native UI at selected edges. For example, to extend to the bottom edge:

```swift
webView.viewportCoordinator.obscuredContentInsetEdges = [.top, .left, .right]
```

Content can still scroll clear of the bottom bar. Use `env(safe-area-inset-bottom)` to keep fixed controls above it:

```css
.bottom-controls {
    position: fixed;
    bottom: env(safe-area-inset-bottom);
}
```

Keep the default `.all` when the page does not handle these CSS insets. Keyboard and input accessory avoidance, along with any additional obscured insets, apply regardless of this setting.
