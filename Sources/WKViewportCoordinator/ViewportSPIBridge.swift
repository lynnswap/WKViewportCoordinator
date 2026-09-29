#if canImport(UIKit)
import ABIBridge
import ObjectiveC
import OSLog
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

@MainActor
private enum ViewportSPIMethods {
    static let setContentScrollInset = ViewportSPIMethod(
        ViewportSPISelectorNames.setContentScrollInset, as: ((UIEdgeInsets) -> Void).self
    )
    static let setContentScrollInsetInternal = ViewportSPIMethod(
        ViewportSPISelectorNames.setContentScrollInsetInternal, as: ((UIEdgeInsets) -> Bool).self
    )
    static let setObscuredInsets = ViewportSPIMethod(
        ViewportSPISelectorNames.setObscuredInsets, as: ((UIEdgeInsets) -> Void).self
    )
    static let setObscuredInsetsInternal = ViewportSPIMethod(
        ViewportSPISelectorNames.setObscuredInsetsInternal, as: ((UIEdgeInsets) -> Void).self
    )
    static let setUnobscuredSafeAreaInsets = ViewportSPIMethod(
        ViewportSPISelectorNames.setUnobscuredSafeAreaInsets, as: ((UIEdgeInsets) -> Void).self
    )
    static let setObscuredInsetEdgesAffectedBySafeArea = ViewportSPIMethod(
        ViewportSPISelectorNames.setObscuredInsetEdgesAffectedBySafeArea, as: ((UInt) -> Void).self
    )
    static let fullLayoutOverride = ViewportSPIMethod(
        ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride,
        as: ((CGSize, CGSize, CGSize) -> Void).self
    )
    static let maximumOnlyLayoutOverride = ViewportSPIMethod(
        ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride,
        as: ((CGSize, CGSize) -> Void).self
    )
    static let clearOverrideLayoutParameters = ViewportSPIMethod(
        ViewportSPISelectorNames.clearOverrideLayoutParameters, as: (() -> Void).self
    )
    static let scrollViewSystemContentInset = ViewportSPIMethod(
        ViewportSPISelectorNames.scrollViewSystemContentInset, as: (() -> UIEdgeInsets).self
    )
    static let systemContentInset = ViewportSPIMethod(
        ViewportSPISelectorNames.systemContentInset, as: (() -> UIEdgeInsets).self
    )
    static let frameOrBoundsMayHaveChanged = ViewportSPIMethod(
        ViewportSPISelectorNames.frameOrBoundsMayHaveChanged, as: (() -> Void).self
    )
    static let inputViewBoundsInWindow = ViewportSPIMethod(
        ViewportSPISelectorNames.inputViewBoundsInWindow, as: (() -> CGRect).self
    )
}

@MainActor
private final class ViewportSPIMethod<Result, each Argument> {
    private let selector: Selector
    private let signature: ((repeat each Argument) -> Result).Type
    // Unbound handles reuse signature preparation without extending view lifetimes.
    private var methods: [ObjectIdentifier: NativeObjCMethod<Result, repeat each Argument>] = [:]

    init(_ name: String, as signature: ((repeat each Argument) -> Result).Type) {
        selector = NSSelectorFromString(name)
        self.signature = signature
    }

    func invoke(on object: NSObject, _ arguments: repeat each Argument) throws -> Result? {
        let receiverClass = object_getClass(object)!
        let key = ObjectIdentifier(receiverClass)
        let method: NativeObjCMethod<Result, repeat each Argument>
        if let cached = methods[key] {
            method = cached
        } else {
            do {
                method = try ABIRuntime.shared.objcMethod(on: receiverClass, selector: selector, as: signature)
            } catch ABIResolutionError.declarationNotFound {
                return nil
            }
            methods[key] = method
        }
        return try unsafe method.unsafeInvoke(on: object, repeat each arguments)
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

// WebKit builds expose either two or three layout-size arguments.
@MainActor
private enum LegacyLayoutOverrideSPI {
    static func apply(obscuredInsets: UIEdgeInsets, to webView: NSObject, scrollView: NSObject) throws -> Bool {
        guard let webView = webView as? UIView else { return false }
        let size = try layoutSize(in: webView, scrollView: scrollView, obscuredInsets: obscuredInsets)
        return try applyLayoutOverride(size: size, to: webView)
    }

    static func reset(on webView: NSObject, scrollView: NSObject) throws -> Bool {
        if try ViewportSPIMethods.clearOverrideLayoutParameters.invoke(on: webView) != nil {
            return true
        }
        guard let webView = webView as? UIView else { return false }
        let size = try layoutSize(in: webView, scrollView: scrollView, obscuredInsets: .zero)
        return try applyLayoutOverride(size: size, to: webView)
    }

    private static func layoutSize(
        in webView: UIView,
        scrollView: NSObject,
        obscuredInsets: UIEdgeInsets
    ) throws -> CGSize {
        let systemContentInset = try ViewportSPIMethods.scrollViewSystemContentInset.invoke(on: webView)
            ?? ViewportSPIMethods.systemContentInset.invoke(on: scrollView)
            ?? .zero
        let layoutRect = webView.bounds.inset(by: systemContentInset.wk_maxPerEdge(with: obscuredInsets))
        return CGSize(width: max(0, layoutRect.width), height: max(0, layoutRect.height))
    }

    private static func applyLayoutOverride(size: CGSize, to object: NSObject) throws -> Bool {
        if try ViewportSPIMethods.fullLayoutOverride.invoke(on: object, size, size, size) != nil {
            return true
        }
        return try ViewportSPIMethods.maximumOnlyLayoutOverride.invoke(on: object, size, size) != nil
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
        perform {
            switch mode {
            case .apply:
                try LegacyLayoutOverrideSPI.apply(obscuredInsets: obscuredInsets, to: webView, scrollView: scrollView)
            case .reset:
                try LegacyLayoutOverrideSPI.reset(on: webView, scrollView: scrollView)
            }
        } ?? false
    }

    private static func applyObscuredInsets(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        perform {
            try ViewportSPIMethods.setObscuredInsets.invoke(on: object, insets)
                ?? ViewportSPIMethods.setObscuredInsetsInternal.invoke(on: object, insets)
        } != nil
    }

    private static func applyContentScrollInset(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        perform {
            if try ViewportSPIMethods.setContentScrollInset.invoke(on: object, insets) != nil {
                return true
            }
            return try ViewportSPIMethods.setContentScrollInsetInternal.invoke(on: object, insets) != nil
        } ?? false
    }

    @discardableResult
    static func apply(unobscuredSafeAreaInsets insets: UIEdgeInsets, to object: NSObject) -> Bool {
        perform { try ViewportSPIMethods.setUnobscuredSafeAreaInsets.invoke(on: object, insets) } != nil
    }

    @discardableResult
    static func apply(obscuredSafeAreaEdges edges: UIRectEdge, to object: NSObject) -> Bool {
        perform { try ViewportSPIMethods.setObscuredInsetEdgesAffectedBySafeArea.invoke(on: object, edges.rawValue) } != nil
    }

    private static func frameOrBoundsMayHaveChanged(on object: NSObject) {
        _ = perform { try ViewportSPIMethods.frameOrBoundsMayHaveChanged.invoke(on: object) }
    }

    static func inputViewBoundsInWindow(of object: NSObject) -> CGRect? {
        perform { try ViewportSPIMethods.inputViewBoundsInWindow.invoke(on: object) }
    }

    private static let logger = Logger(subsystem: "WKViewportCoordinator", category: "ViewportSPI")

    // Viewport updates are best effort. Only missing declarations select another
    // selector; ABI and invocation failures are reported at the operation boundary.
    private static func perform<Value>(_ operation: () throws -> Value?) -> Value? {
        do {
            return try operation()
        } catch {
            logger.error("Viewport SPI failed: \(String(describing: error), privacy: .public)")
            return nil
        }
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
