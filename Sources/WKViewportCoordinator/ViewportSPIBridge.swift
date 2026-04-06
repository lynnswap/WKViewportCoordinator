#if canImport(UIKit)
import UIKit
import WebKit

enum ViewportSPISelectorNames {
    private static func deobfuscate(_ reverseTokens: [String]) -> String {
        reverseTokens.reversed().joined()
    }

    static let setUnobscuredSafeAreaInsets = deobfuscate([":", "Insets", "Area", "Safe", "Unobscured", "set", "_"])
    static let setObscuredInsetEdgesAffectedBySafeArea = deobfuscate([
        ":", "Area", "Safe", "By", "Affected", "Edges", "Inset", "Obscured", "set", "_"
    ])
    static let setObscuredInsets = deobfuscate([":", "Insets", "Obscured", "set", "_"])
    static let setObscuredInsetsInternal = deobfuscate([":", "Internal", "Insets", "Obscured", "set", "_"])
    static let setContentScrollInset = deobfuscate([":", "Inset", "Scroll", "Content", "set", "_"])
    static let setContentScrollInsetInternal = deobfuscate([":", "Internal", "Inset", "Scroll", "Content", "set", "_"])
    static let overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride = deobfuscate([
        ":", "Override", "Size", "Unobscured", "maximum", ":",
        "Size", "Layout", "Minimum", "With", "Parameters", "Layout", "override", "_"
    ])
    static let overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride = deobfuscate([
        ":", "Override", "Size", "Unobscured", "maximum", ":",
        "Override", "Size", "Unobscured", "minimum", ":",
        "Size", "Layout", "Minimum", "With", "Parameters", "Layout", "override", "_"
    ])
    static let clearOverrideLayoutParameters = deobfuscate(["Parameters", "Layout", "Override", "clear", "_"])
    static let scrollViewSystemContentInset = deobfuscate(["Inset", "Content", "System", "View", "scroll", "_"])
    static let systemContentInset = deobfuscate(["Inset", "Content", "system", "_"])
    static let frameOrBoundsMayHaveChanged = deobfuscate(["Changed", "Have", "May", "Bounds", "Or", "frame", "_"])
    static let inputViewBoundsInWindow = deobfuscate(["Window", "In", "Bounds", "View", "input", "_"])
}

@MainActor
enum ViewportSPIBridge {
    private static let setContentScrollInsetSelector = NSSelectorFromString(
        ViewportSPISelectorNames.setContentScrollInset
    )
    private static let setContentScrollInsetInternalSelector = NSSelectorFromString(
        ViewportSPISelectorNames.setContentScrollInsetInternal
    )
    private static let setObscuredInsetsInternalSelector = NSSelectorFromString(
        ViewportSPISelectorNames.setObscuredInsetsInternal
    )
    private static let setObscuredInsetsSelector = NSSelectorFromString(
        ViewportSPISelectorNames.setObscuredInsets
    )
    private static let setUnobscuredSafeAreaInsetsSelector = NSSelectorFromString(
        ViewportSPISelectorNames.setUnobscuredSafeAreaInsets
    )
    private static let setObscuredInsetEdgesAffectedBySafeAreaSelector = NSSelectorFromString(
        ViewportSPISelectorNames.setObscuredInsetEdgesAffectedBySafeArea
    )
    private static let overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverrideSelector = NSSelectorFromString(
        ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride
    )
    private static let overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverrideSelector =
        NSSelectorFromString(
            ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride
        )
    private static let clearOverrideLayoutParametersSelector = NSSelectorFromString(
        ViewportSPISelectorNames.clearOverrideLayoutParameters
    )
    private static let scrollViewSystemContentInsetSelector = NSSelectorFromString(
        ViewportSPISelectorNames.scrollViewSystemContentInset
    )
    private static let systemContentInsetSelector = NSSelectorFromString(
        ViewportSPISelectorNames.systemContentInset
    )
    private static let frameOrBoundsMayHaveChangedSelector = NSSelectorFromString(
        ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
    )
    private static let inputViewBoundsInWindowSelector = NSSelectorFromString(
        ViewportSPISelectorNames.inputViewBoundsInWindow
    )

    @discardableResult
    static func applyLegacyViewportFallback(
        _ resolvedMetrics: ResolvedViewportMetrics,
        to scrollView: NSObject,
        webView: NSObject
    ) -> Bool {
        applyLegacyViewportState(
            contentScrollInset: resolvedMetrics.contentScrollInsetFallback,
            obscuredInsets: resolvedMetrics.obscuredInsets,
            unobscuredSafeAreaInsets: resolvedMetrics.unobscuredSafeAreaInsets,
            obscuredSafeAreaEdges: resolvedMetrics.safeAreaAffectedEdges,
            clearLayoutOverride: false,
            to: scrollView,
            webView: webView
        )
    }

    @discardableResult
    static func resetLegacyViewportFallback(
        on scrollView: NSObject,
        webView: NSObject
    ) -> Bool {
        applyLegacyViewportState(
            contentScrollInset: .zero,
            obscuredInsets: .zero,
            unobscuredSafeAreaInsets: .zero,
            obscuredSafeAreaEdges: [],
            clearLayoutOverride: true,
            to: scrollView,
            webView: webView
        )
    }

    private static func applyLegacyViewportState(
        contentScrollInset: UIEdgeInsets,
        obscuredInsets: UIEdgeInsets,
        unobscuredSafeAreaInsets: UIEdgeInsets,
        obscuredSafeAreaEdges: UIRectEdge,
        clearLayoutOverride: Bool,
        to scrollView: NSObject,
        webView: NSObject
    ) -> Bool {
        let didApplyContentScrollInset = applyContentScrollInset(
            contentScrollInset,
            to: scrollView
        )
        let didApplyObscuredInsets = applyObscuredInsetsInternal(
            obscuredInsets,
            to: webView
        )
        let didApplyUnobscuredSafeAreaInsets = apply(
            unobscuredSafeAreaInsets: unobscuredSafeAreaInsets,
            to: webView
        )
        let didApplyObscuredSafeAreaEdges = apply(
            obscuredSafeAreaEdges: obscuredSafeAreaEdges,
            to: webView
        )
        let didApplyLayoutOverride: Bool
        if clearLayoutOverride {
            didApplyLayoutOverride = clearOverrideLayoutParameters(on: webView)
        } else {
            didApplyLayoutOverride = applyLegacyLayoutOverride(
                obscuredInsets: obscuredInsets,
                to: webView,
                scrollView: scrollView
            )
        }

        guard
            didApplyContentScrollInset
                || didApplyObscuredInsets
                || didApplyUnobscuredSafeAreaInsets
                || didApplyObscuredSafeAreaEdges
                || didApplyLayoutOverride
        else {
            return false
        }

        frameOrBoundsMayHaveChanged(on: webView)
        return true
    }

    private static func applyObscuredInsetsInternal(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        if object.responds(to: Self.setObscuredInsetsSelector) {
            let selector = Self.setObscuredInsetsSelector
            typealias Setter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Void
            let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Setter.self)
            implementation(object, selector, insets)
            return true
        }

        guard object.responds(to: Self.setObscuredInsetsInternalSelector) else {
            return false
        }

        let selector = Self.setObscuredInsetsInternalSelector
        typealias Setter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Void
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Setter.self)
        implementation(object, selector, insets)
        return true
    }

    private static func applyContentScrollInset(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        if object.responds(to: Self.setContentScrollInsetSelector) {
            let selector = Self.setContentScrollInsetSelector
            typealias Setter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Void
            let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Setter.self)
            implementation(object, selector, insets)
            return true
        }

        guard object.responds(to: Self.setContentScrollInsetInternalSelector) else {
            return false
        }

        let selector = Self.setContentScrollInsetInternalSelector
        typealias Setter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Bool
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Setter.self)
        _ = implementation(object, selector, insets)
        return true
    }

    @MainActor
    private static func applyLegacyLayoutOverride(
        obscuredInsets: UIEdgeInsets,
        to webView: NSObject,
        scrollView: NSObject
    ) -> Bool {
        guard let boundsValue = webView.value(forKey: "bounds") as? NSValue else {
            return false
        }
        let bounds = boundsValue.cgRectValue
        let systemContentInset = scrollViewSystemContentInset(of: webView)
            ?? systemContentInset(of: scrollView)
            ?? .zero
        let layoutInsets = systemContentInset.wk_maxPerEdge(with: obscuredInsets)
        let unobscuredRect = bounds.inset(by: layoutInsets)
        let layoutSize = CGSize(
            width: max(0, unobscuredRect.width),
            height: max(0, unobscuredRect.height)
        )

        if webView.responds(to: Self.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverrideSelector) {
            let selector = Self.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverrideSelector
            typealias Setter = @convention(c) (NSObject, Selector, CGSize, CGSize, CGSize) -> Void
            let implementation = unsafe unsafeBitCast(webView.method(for: selector), to: Setter.self)
            implementation(webView, selector, layoutSize, layoutSize, layoutSize)
            return true
        }

        guard webView.responds(to: Self.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverrideSelector) else {
            return false
        }

        let selector = Self.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverrideSelector
        typealias Setter = @convention(c) (NSObject, Selector, CGSize, CGSize) -> Void
        let implementation = unsafe unsafeBitCast(webView.method(for: selector), to: Setter.self)
        implementation(webView, selector, layoutSize, layoutSize)
        return true
    }

    private static func clearOverrideLayoutParameters(on object: NSObject) -> Bool {
        let selector = Self.clearOverrideLayoutParametersSelector
        guard object.responds(to: selector) else {
            return false
        }

        typealias Method = @convention(c) (NSObject, Selector) -> Void
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Method.self)
        implementation(object, selector)
        return true
    }

    private static func scrollViewSystemContentInset(of object: NSObject) -> UIEdgeInsets? {
        let selector = Self.scrollViewSystemContentInsetSelector
        guard object.responds(to: selector) else {
            return nil
        }

        typealias Getter = @convention(c) (NSObject, Selector) -> UIEdgeInsets
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Getter.self)
        return implementation(object, selector)
    }

    private static func systemContentInset(of object: NSObject) -> UIEdgeInsets? {
        let selector = Self.systemContentInsetSelector
        guard object.responds(to: selector) else {
            return nil
        }

        typealias Getter = @convention(c) (NSObject, Selector) -> UIEdgeInsets
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Getter.self)
        return implementation(object, selector)
    }

    @discardableResult
    static func apply(unobscuredSafeAreaInsets insets: UIEdgeInsets, to object: NSObject) -> Bool {
        let selector = Self.setUnobscuredSafeAreaInsetsSelector
        guard object.responds(to: selector) else {
            return false
        }

        typealias Setter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Void
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Setter.self)
        implementation(object, selector, insets)
        return true
    }

    @discardableResult
    static func apply(obscuredSafeAreaEdges edges: UIRectEdge, to object: NSObject) -> Bool {
        let selector = Self.setObscuredInsetEdgesAffectedBySafeAreaSelector
        guard object.responds(to: selector) else {
            return false
        }

        typealias Setter = @convention(c) (NSObject, Selector, UInt) -> Void
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Setter.self)
        implementation(object, selector, edges.rawValue)
        return true
    }

    private static func frameOrBoundsMayHaveChanged(on object: NSObject) {
        let selector = Self.frameOrBoundsMayHaveChangedSelector
        guard object.responds(to: selector) else {
            return
        }

        typealias Method = @convention(c) (NSObject, Selector) -> Void
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Method.self)
        implementation(object, selector)
    }

    static func inputViewBoundsInWindow(of object: NSObject) -> CGRect? {
        let selector = Self.inputViewBoundsInWindowSelector
        guard object.responds(to: selector) else {
            return nil
        }

        typealias Getter = @convention(c) (NSObject, Selector) -> CGRect
        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: Getter.self)
        return implementation(object, selector)
    }
}

private extension UIEdgeInsets {
    func wk_maxPerEdge(with other: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(top, other.top),
            left: max(left, other.left),
            bottom: max(bottom, other.bottom),
            right: max(right, other.right)
        )
    }
}
#endif
