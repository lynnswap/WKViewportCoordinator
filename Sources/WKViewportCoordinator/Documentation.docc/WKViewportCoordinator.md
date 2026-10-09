# ``WKViewportCoordinator``

Coordinate a web view's layout viewport with its UIKit host.

## Overview

Use ``ViewportWebView`` to keep web content inside the window and container safe areas. The coordinator measures geometry in the web view's coordinate space, including native bars at the top, bottom, or sides and keyboard and input accessory overlap.

``ViewportWebView`` owns a ``ViewportCoordinator`` and forwards layout, hierarchy, and safe-area changes. Configure viewport behavior through ``ViewportWebView/viewportCoordinator``; configure scroll behavior and appearance through the inherited `scrollView` property.

Use ``ViewportCoordinator`` directly for an existing web view subclass. Retain it and call ``ViewportCoordinator/update()`` from the web view's layout, hierarchy, and safe-area callbacks. Set ``ViewportCoordinator/hostViewController`` when the responder chain does not identify the intended host.

The coordinator adds its scroll inset contribution without replacing insets owned by the application or UIKit. Calling ``ViewportCoordinator/invalidate()`` removes that contribution, releases WebKit overrides, and permanently stops observation. The scroll view's automatic adjustment setting is preserved.

> Warning: This package uses undocumented WebKit APIs. Unavailable SPI can leave viewport updates or restoration incomplete. Validate behavior on each supported OS version.

## Topics

### Automatic coordination

- ``ViewportWebView``

### Existing web views

- ``ViewportCoordinator``
