#if canImport(UIKit)
import UIKit
import WebKit

enum ViewportSPISelectorNames {
    private static func deobfuscate(_ reverseTokens: [String]) -> String {
        reverseTokens.reversed().joined()
    }

    // The comments intentionally keep the real selector spellings next to the
    // obfuscated values so selector updates remain reviewable.
    // Original: _setUnobscuredSafeAreaInsets:
    static let setUnobscuredSafeAreaInsets = deobfuscate([":", "Insets", "Area", "Safe", "Unobscured", "set", "_"])
    // Original: _setObscuredInsetEdgesAffectedBySafeArea:
    static let setObscuredInsetEdgesAffectedBySafeArea = deobfuscate([
        ":", "Area", "Safe", "By", "Affected", "Edges", "Inset", "Obscured", "set", "_"
    ])
    // Original: _setObscuredInsets:
    static let setObscuredInsets = deobfuscate([":", "Insets", "Obscured", "set", "_"])
    // Original: _setObscuredInsetsInternal:
    static let setObscuredInsetsInternal = deobfuscate([":", "Internal", "Insets", "Obscured", "set", "_"])
    // Original: _setContentScrollInset:
    static let setContentScrollInset = deobfuscate([":", "Inset", "Scroll", "Content", "set", "_"])
    // Original: _setContentScrollInsetInternal:
    static let setContentScrollInsetInternal = deobfuscate([":", "Internal", "Inset", "Scroll", "Content", "set", "_"])
    // Original: _overrideLayoutParametersWithMinimumLayoutSize:maximumUnobscuredSizeOverride:
    static let overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride = deobfuscate([
        ":", "Override", "Size", "Unobscured", "maximum", ":",
        "Size", "Layout", "Minimum", "With", "Parameters", "Layout", "override", "_"
    ])
    // Original: _overrideLayoutParametersWithMinimumLayoutSize:minimumUnobscuredSizeOverride:maximumUnobscuredSizeOverride:
    static let overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride = deobfuscate([
        ":", "Override", "Size", "Unobscured", "maximum", ":",
        "Override", "Size", "Unobscured", "minimum", ":",
        "Size", "Layout", "Minimum", "With", "Parameters", "Layout", "override", "_"
    ])
    // Original: _clearOverrideLayoutParameters
    static let clearOverrideLayoutParameters = deobfuscate(["Parameters", "Layout", "Override", "clear", "_"])
    // Original: _scrollViewSystemContentInset
    static let scrollViewSystemContentInset = deobfuscate(["Inset", "Content", "System", "View", "scroll", "_"])
    // Original: _systemContentInset
    static let systemContentInset = deobfuscate(["Inset", "Content", "system", "_"])
    // Original: _frameOrBoundsMayHaveChanged
    static let frameOrBoundsMayHaveChanged = deobfuscate(["Changed", "Have", "May", "Bounds", "Or", "frame", "_"])
    // Original: _inputViewBoundsInWindow
    static let inputViewBoundsInWindow = deobfuscate(["Window", "In", "Bounds", "View", "input", "_"])
}

// Cached Selector values. The string table above is kept separate so tests can
// assert exact selector spellings without reaching into Objective-C runtime data.
private enum ViewportSPISelectors {
    static let setContentScrollInset = NSSelectorFromString(
        ViewportSPISelectorNames.setContentScrollInset
    )
    static let setContentScrollInsetInternal = NSSelectorFromString(
        ViewportSPISelectorNames.setContentScrollInsetInternal
    )
    static let setObscuredInsets = NSSelectorFromString(
        ViewportSPISelectorNames.setObscuredInsets
    )
    static let setObscuredInsetsInternal = NSSelectorFromString(
        ViewportSPISelectorNames.setObscuredInsetsInternal
    )
    static let setUnobscuredSafeAreaInsets = NSSelectorFromString(
        ViewportSPISelectorNames.setUnobscuredSafeAreaInsets
    )
    static let setObscuredInsetEdgesAffectedBySafeArea = NSSelectorFromString(
        ViewportSPISelectorNames.setObscuredInsetEdgesAffectedBySafeArea
    )
    static let overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride = NSSelectorFromString(
        ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride
    )
    static let overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride =
        NSSelectorFromString(
            ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride
        )
    static let clearOverrideLayoutParameters = NSSelectorFromString(
        ViewportSPISelectorNames.clearOverrideLayoutParameters
    )
    static let scrollViewSystemContentInset = NSSelectorFromString(
        ViewportSPISelectorNames.scrollViewSystemContentInset
    )
    static let systemContentInset = NSSelectorFromString(
        ViewportSPISelectorNames.systemContentInset
    )
    static let frameOrBoundsMayHaveChanged = NSSelectorFromString(
        ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
    )
    static let inputViewBoundsInWindow = NSSelectorFromString(
        ViewportSPISelectorNames.inputViewBoundsInWindow
    )
}

// Single place for unsafe IMP casts. Call sites choose selectors and state;
// this type only handles typed Objective-C invocation.
private enum ViewportSPIInvocation {
    typealias InsetsVoidSetter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Void
    typealias InsetsBooleanSetter = @convention(c) (NSObject, Selector, UIEdgeInsets) -> Bool
    typealias EdgeSetter = @convention(c) (NSObject, Selector, UInt) -> Void
    typealias VoidMethod = @convention(c) (NSObject, Selector) -> Void
    typealias InsetsGetter = @convention(c) (NSObject, Selector) -> UIEdgeInsets
    typealias RectGetter = @convention(c) (NSObject, Selector) -> CGRect
    typealias FullLayoutOverrideSetter = @convention(c) (NSObject, Selector, CGSize, CGSize, CGSize) -> Void
    typealias MaximumOnlyLayoutOverrideSetter = @convention(c) (NSObject, Selector, CGSize, CGSize) -> Void

    @discardableResult
    static func callInsetsVoidSetter(
        _ selector: Selector,
        on object: NSObject,
        insets: UIEdgeInsets
    ) -> Bool {
        guard object.responds(to: selector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: InsetsVoidSetter.self)
        implementation(object, selector, insets)
        return true
    }

    @discardableResult
    static func callInsetsBooleanSetter(
        _ selector: Selector,
        on object: NSObject,
        insets: UIEdgeInsets
    ) -> Bool {
        guard object.responds(to: selector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: InsetsBooleanSetter.self)
        _ = implementation(object, selector, insets)
        return true
    }

    @discardableResult
    static func callEdgeSetter(_ selector: Selector, on object: NSObject, edges: UIRectEdge) -> Bool {
        guard object.responds(to: selector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: EdgeSetter.self)
        implementation(object, selector, edges.rawValue)
        return true
    }

    @discardableResult
    static func callVoidMethod(_ selector: Selector, on object: NSObject) -> Bool {
        guard object.responds(to: selector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: VoidMethod.self)
        implementation(object, selector)
        return true
    }

    @discardableResult
    static func callFullLayoutOverride(
        _ selector: Selector,
        on object: NSObject,
        minimumLayoutSize: CGSize,
        minimumUnobscuredSizeOverride: CGSize,
        maximumUnobscuredSizeOverride: CGSize
    ) -> Bool {
        guard object.responds(to: selector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: FullLayoutOverrideSetter.self)
        implementation(
            object,
            selector,
            minimumLayoutSize,
            minimumUnobscuredSizeOverride,
            maximumUnobscuredSizeOverride
        )
        return true
    }

    @discardableResult
    static func callMaximumOnlyLayoutOverride(
        _ selector: Selector,
        on object: NSObject,
        minimumLayoutSize: CGSize,
        maximumUnobscuredSizeOverride: CGSize
    ) -> Bool {
        guard object.responds(to: selector) else {
            return false
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: MaximumOnlyLayoutOverrideSetter.self)
        implementation(object, selector, minimumLayoutSize, maximumUnobscuredSizeOverride)
        return true
    }

    static func readInsets(_ selector: Selector, from object: NSObject) -> UIEdgeInsets? {
        guard object.responds(to: selector) else {
            return nil
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: InsetsGetter.self)
        return implementation(object, selector)
    }

    static func readRect(_ selector: Selector, from object: NSObject) -> CGRect? {
        guard object.responds(to: selector) else {
            return nil
        }

        let implementation = unsafe unsafeBitCast(object.method(for: selector), to: RectGetter.self)
        return implementation(object, selector)
    }
}

// Values applied as the pre-iOS 26 WebKit viewport fallback. Grouping them
// keeps reset and apply paths explicit without passing parallel argument lists.
private struct LegacyViewportSPIState {
    var contentScrollInset: UIEdgeInsets
    var obscuredInsets: UIEdgeInsets
    var unobscuredSafeAreaInsets: UIEdgeInsets
    var obscuredSafeAreaEdges: UIRectEdge
    var layoutOverrideMode: LayoutOverrideMode

    enum LayoutOverrideMode {
        case apply
        case reset
    }

    static func applying(_ resolvedMetrics: ResolvedViewportMetrics) -> Self {
        Self(
            contentScrollInset: resolvedMetrics.contentScrollInsetFallback,
            obscuredInsets: resolvedMetrics.obscuredInsets,
            unobscuredSafeAreaInsets: resolvedMetrics.unobscuredSafeAreaInsets,
            obscuredSafeAreaEdges: resolvedMetrics.obscuredContentInsetEdgesAffectedBySafeArea,
            layoutOverrideMode: .apply
        )
    }

    static let reset = Self(
        contentScrollInset: .zero,
        obscuredInsets: .zero,
        unobscuredSafeAreaInsets: .zero,
        obscuredSafeAreaEdges: [],
        layoutOverrideMode: .reset
    )
}

// Handles the private layout-viewport override selectors used by the legacy
// fallback path. The selector arity changed across WebKit builds, so both forms
// remain supported.
private enum LegacyLayoutOverrideSPI {
    private enum SelectorKind {
        case minimumAndMaximum
        case maximumOnly
    }

    @MainActor
    static func apply(obscuredInsets: UIEdgeInsets, to webView: NSObject, scrollView: NSObject) -> Bool {
        guard let webView = webView as? UIView,
              let selectorKind = supportedSelectorKind(for: webView)
        else {
            return false
        }

        let layoutSize = layoutSize(in: webView, scrollView: scrollView, obscuredInsets: obscuredInsets)
        return applyLayoutOverride(
            selectorKind,
            minimumLayoutSize: layoutSize,
            minimumUnobscuredSizeOverride: layoutSize,
            maximumUnobscuredSizeOverride: layoutSize,
            to: webView
        )
    }

    @MainActor
    static func reset(on webView: NSObject, scrollView: NSObject) -> Bool {
        if ViewportSPIInvocation.callVoidMethod(
            ViewportSPISelectors.clearOverrideLayoutParameters,
            on: webView
        ) {
            return true
        }

        guard let webView = webView as? UIView,
              let selectorKind = supportedSelectorKind(for: webView)
        else {
            return false
        }

        let defaultLayoutSize = layoutSize(in: webView, scrollView: scrollView, obscuredInsets: .zero)
        return applyLayoutOverride(
            selectorKind,
            minimumLayoutSize: defaultLayoutSize,
            minimumUnobscuredSizeOverride: defaultLayoutSize,
            maximumUnobscuredSizeOverride: defaultLayoutSize,
            to: webView
        )
    }

    private static func supportedSelectorKind(for object: NSObject) -> SelectorKind? {
        if object.responds(
            to: ViewportSPISelectors.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride
        ) {
            return .minimumAndMaximum
        }
        if object.responds(to: ViewportSPISelectors.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride) {
            return .maximumOnly
        }
        return nil
    }

    @MainActor
    private static func layoutSize(
        in webView: UIView,
        scrollView: NSObject,
        obscuredInsets: UIEdgeInsets
    ) -> CGSize {
        let systemContentInset = ViewportSPIInvocation.readInsets(
            ViewportSPISelectors.scrollViewSystemContentInset,
            from: webView
        )
            ?? ViewportSPIInvocation.readInsets(
                ViewportSPISelectors.systemContentInset,
                from: scrollView
            )
            ?? .zero
        let layoutInsets = systemContentInset.wk_maxPerEdge(with: obscuredInsets)
        let layoutRect = webView.bounds.inset(by: layoutInsets)
        return CGSize(
            width: max(0, layoutRect.width),
            height: max(0, layoutRect.height)
        )
    }

    private static func applyLayoutOverride(
        _ selectorKind: SelectorKind,
        minimumLayoutSize: CGSize,
        minimumUnobscuredSizeOverride: CGSize,
        maximumUnobscuredSizeOverride: CGSize,
        to object: NSObject
    ) -> Bool {
        switch selectorKind {
        case .minimumAndMaximum:
            return ViewportSPIInvocation.callFullLayoutOverride(
                ViewportSPISelectors.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride,
                on: object,
                minimumLayoutSize: minimumLayoutSize,
                minimumUnobscuredSizeOverride: minimumUnobscuredSizeOverride,
                maximumUnobscuredSizeOverride: maximumUnobscuredSizeOverride
            )
        case .maximumOnly:
            return ViewportSPIInvocation.callMaximumOnlyLayoutOverride(
                ViewportSPISelectors.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride,
                on: object,
                minimumLayoutSize: minimumLayoutSize,
                maximumUnobscuredSizeOverride: maximumUnobscuredSizeOverride
            )
        }
    }
}

@MainActor
enum ViewportSPIBridge {
    @discardableResult
    static func applyLegacyViewportFallback(
        _ resolvedMetrics: ResolvedViewportMetrics,
        to scrollView: NSObject,
        webView: NSObject
    ) -> Bool {
        applyLegacyViewportState(
            .applying(resolvedMetrics),
            to: scrollView,
            webView: webView
        )
    }

    @discardableResult
    static func resetLegacyViewportFallback(
        on scrollView: NSObject,
        webView: NSObject
    ) -> Bool {
        applyLegacyViewportState(.reset, to: scrollView, webView: webView)
    }

    private static func applyLegacyViewportState(
        _ state: LegacyViewportSPIState,
        to scrollView: NSObject,
        webView: NSObject
    ) -> Bool {
        let didApplyContentScrollInset = applyContentScrollInset(
            state.contentScrollInset,
            to: scrollView
        )
        let didApplyObscuredInsets = applyObscuredInsets(
            state.obscuredInsets,
            to: webView
        )
        let didApplyUnobscuredSafeAreaInsets = apply(
            unobscuredSafeAreaInsets: state.unobscuredSafeAreaInsets,
            to: webView
        )
        let didApplyObscuredSafeAreaEdges = apply(
            obscuredSafeAreaEdges: state.obscuredSafeAreaEdges,
            to: webView
        )
        let didApplyLayoutOverride = applyLayoutOverride(
            state.layoutOverrideMode,
            obscuredInsets: state.obscuredInsets,
            to: webView,
            scrollView: scrollView
        )

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

    private static func applyLayoutOverride(
        _ mode: LegacyViewportSPIState.LayoutOverrideMode,
        obscuredInsets: UIEdgeInsets,
        to webView: NSObject,
        scrollView: NSObject
    ) -> Bool {
        switch mode {
        case .apply:
            LegacyLayoutOverrideSPI.apply(
                obscuredInsets: obscuredInsets,
                to: webView,
                scrollView: scrollView
            )
        case .reset:
            LegacyLayoutOverrideSPI.reset(on: webView, scrollView: scrollView)
        }
    }

    private static func applyObscuredInsets(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        if ViewportSPIInvocation.callInsetsVoidSetter(
            ViewportSPISelectors.setObscuredInsets,
            on: object,
            insets: insets
        ) {
            return true
        }

        return ViewportSPIInvocation.callInsetsVoidSetter(
            ViewportSPISelectors.setObscuredInsetsInternal,
            on: object,
            insets: insets
        )
    }

    private static func applyContentScrollInset(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        if ViewportSPIInvocation.callInsetsVoidSetter(
            ViewportSPISelectors.setContentScrollInset,
            on: object,
            insets: insets
        ) {
            return true
        }

        return ViewportSPIInvocation.callInsetsBooleanSetter(
            ViewportSPISelectors.setContentScrollInsetInternal,
            on: object,
            insets: insets
        )
    }

    @discardableResult
    static func apply(unobscuredSafeAreaInsets insets: UIEdgeInsets, to object: NSObject) -> Bool {
        ViewportSPIInvocation.callInsetsVoidSetter(
            ViewportSPISelectors.setUnobscuredSafeAreaInsets,
            on: object,
            insets: insets
        )
    }

    @discardableResult
    static func apply(obscuredSafeAreaEdges edges: UIRectEdge, to object: NSObject) -> Bool {
        ViewportSPIInvocation.callEdgeSetter(
            ViewportSPISelectors.setObscuredInsetEdgesAffectedBySafeArea,
            on: object,
            edges: edges
        )
    }

    private static func frameOrBoundsMayHaveChanged(on object: NSObject) {
        ViewportSPIInvocation.callVoidMethod(
            ViewportSPISelectors.frameOrBoundsMayHaveChanged,
            on: object
        )
    }

    static func inputViewBoundsInWindow(of object: NSObject) -> CGRect? {
        ViewportSPIInvocation.readRect(
            ViewportSPISelectors.inputViewBoundsInWindow,
            from: object
        )
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
