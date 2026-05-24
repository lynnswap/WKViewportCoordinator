# ``WKViewportCoordinator``

Coordinate `WKWebView` viewport geometry with UIKit safe areas, visible chrome, keyboard, and input accessory overlap.

## Overview

`WKViewportCoordinator` keeps a `WKWebView` viewport aligned with the UIKit view hierarchy that hosts it. It measures the host window safe area, visible navigation and bottom chrome, keyboard coverage, and input accessory geometry, then applies the resulting viewport state to the web view.

Use ``ManagedViewportWebView`` for the standard integration path. The subclass installs a coordinator and forwards hierarchy and safe-area lifecycle updates automatically.

Use ``ViewportCoordinator`` directly when you already own a custom `WKWebView` subclass. In that case, forward hierarchy and safe-area changes to the coordinator so it can recompute viewport metrics at the same points as ``ManagedViewportWebView``.

> Warning: This package uses undocumented WebKit runtime behavior for legacy viewport fallback support. Validate it carefully before shipping in App Store-bound apps.

## Topics

### Managed Integration

- ``ManagedViewportWebView``

### Manual Coordination

- ``ViewportCoordinator``
- ``ViewportConfiguration``
- ``ViewportMetricsSource``
- ``ViewportMetricsProvider``

### Viewport Metrics

- ``ViewportMetrics``
- ``ViewportSafeAreaMetrics``
- ``BottomChromeMode``
- ``ScrollEdgeEffectStyle``
