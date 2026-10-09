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
    // Original: _resetObscuredInsets
    static let resetObscuredInsets = deobfuscate(["Insets", "Obscured", "reset", "_"])
    // Original: _resetUnobscuredSafeAreaInsets
    static let resetUnobscuredSafeAreaInsets = deobfuscate(["Insets", "Area", "Safe", "Unobscured", "reset", "_"])
    // Original: _setObscuredInsets:
    static let setObscuredInsets = deobfuscate([":", "Insets", "Obscured", "set", "_"])
    // Original: _setObscuredInsetsInternal:
    static let setObscuredInsetsInternal = deobfuscate([":", "Internal", "Insets", "Obscured", "set", "_"])
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
    static let setObscuredInsets = ViewportSPIMethod(
        ViewportSPISelectorNames.setObscuredInsets, as: ((UIEdgeInsets) -> Void).self
    )
    static let setObscuredInsetsInternal = ViewportSPIMethod(
        ViewportSPISelectorNames.setObscuredInsetsInternal, as: ((UIEdgeInsets) -> Void).self
    )
    static let setUnobscuredSafeAreaInsets = ViewportSPIMethod(
        ViewportSPISelectorNames.setUnobscuredSafeAreaInsets, as: ((UIEdgeInsets) -> Void).self
    )
    static let resetObscuredInsets = ViewportSPIMethod(
        ViewportSPISelectorNames.resetObscuredInsets, as: (() -> Void).self
    )
    static let resetUnobscuredSafeAreaInsets = ViewportSPIMethod(
        ViewportSPISelectorNames.resetUnobscuredSafeAreaInsets, as: (() -> Void).self
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
                method = try ABIRuntime.shared.object(object).method(selector: selector, as: signature).method
            } catch ABIResolutionError.declarationNotFound {
                return nil
            }
            methods[key] = method
        }
        return try unsafe method.unsafeInvoke(on: object, repeat each arguments)
    }
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
        let obscured = applyObscuredInsets(resolvedMetrics.obscuredInsets, to: webView)
        let safeArea = apply(unobscuredSafeAreaInsets: resolvedMetrics.unobscuredSafeAreaInsets, to: webView)
        let layout = perform {
            try LegacyLayoutOverrideSPI.apply(
                obscuredInsets: resolvedMetrics.obscuredInsets, to: webView, scrollView: scrollView
            )
        } ?? false
        frameOrBoundsMayHaveChanged(on: webView)
        return obscured && safeArea && layout
    }

    @discardableResult
    static func resetLegacyViewportFallback(on scrollView: NSObject, webView: NSObject) -> Bool {
        let viewport = resetViewportOverrides(on: webView)
        let layout = perform { try LegacyLayoutOverrideSPI.reset(on: webView, scrollView: scrollView) } ?? false
        frameOrBoundsMayHaveChanged(on: webView)
        return viewport && layout
    }

    @discardableResult
    static func resetViewportOverrides(on webView: NSObject) -> Bool {
        // Setting zero leaves WebKit's explicit-override flags enabled. Release
        // both flags so later safe-area and viewport-fit changes work normally.
        let obscured = perform { try ViewportSPIMethods.resetObscuredInsets.invoke(on: webView) } != nil
        let safeArea = perform { try ViewportSPIMethods.resetUnobscuredSafeAreaInsets.invoke(on: webView) } != nil
        if !obscured || !safeArea {
            logger.error("WebKit could not release viewport overrides (obscured: \(obscured), safe area: \(safeArea))")
        }
        return obscured && safeArea
    }

    private static func applyObscuredInsets(_ insets: UIEdgeInsets, to object: NSObject) -> Bool {
        perform {
            try ViewportSPIMethods.setObscuredInsets.invoke(on: object, insets)
                ?? ViewportSPIMethods.setObscuredInsetsInternal.invoke(on: object, insets)
        } != nil
    }

    @discardableResult
    static func apply(unobscuredSafeAreaInsets insets: UIEdgeInsets, to object: NSObject) -> Bool {
        perform { try ViewportSPIMethods.setUnobscuredSafeAreaInsets.invoke(on: object, insets) } != nil
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
