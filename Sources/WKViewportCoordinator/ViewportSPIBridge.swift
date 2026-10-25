#if canImport(UIKit)
import ABIBridge
import ObjectiveC
import OSLog
import UIKit
import WebKit

// Keep decoding at runtime instead of folding literals into call sites.
@inline(never)
private func decodedSPIString(_ encodedBytes: [UInt8]) -> String {
    let key: UInt8 = 0xA7
    return String(decoding: encodedBytes.map { $0 ^ key }, as: UTF8.self)
}

enum ViewportSPISelectorNames {
    // The comments intentionally keep the real selector spellings next to the
    // obfuscated values so selector updates remain reviewable.
    // Original: _setUnobscuredSafeAreaInsets:
    static let setUnobscuredSafeAreaInsets = decodedSPIString([
        0xF8, 0xD4, 0xC2, 0xD3, 0xF2, 0xC9, 0xC8, 0xC5, 0xD4, 0xC4, 0xD2, 0xD5,
        0xC2, 0xC3, 0xF4, 0xC6, 0xC1, 0xC2, 0xE6, 0xD5, 0xC2, 0xC6, 0xEE, 0xC9,
        0xD4, 0xC2, 0xD3, 0xD4, 0x9D
    ])
    // Original: _resetObscuredInsets
    static let resetObscuredInsets = decodedSPIString([
        0xF8, 0xD5, 0xC2, 0xD4, 0xC2, 0xD3, 0xE8, 0xC5, 0xD4, 0xC4, 0xD2, 0xD5,
        0xC2, 0xC3, 0xEE, 0xC9, 0xD4, 0xC2, 0xD3, 0xD4
    ])
    // Original: _resetUnobscuredSafeAreaInsets
    static let resetUnobscuredSafeAreaInsets = decodedSPIString([
        0xF8, 0xD5, 0xC2, 0xD4, 0xC2, 0xD3, 0xF2, 0xC9, 0xC8, 0xC5, 0xD4, 0xC4,
        0xD2, 0xD5, 0xC2, 0xC3, 0xF4, 0xC6, 0xC1, 0xC2, 0xE6, 0xD5, 0xC2, 0xC6,
        0xEE, 0xC9, 0xD4, 0xC2, 0xD3, 0xD4
    ])
    // Original: _setObscuredInsets:
    static let setObscuredInsets = decodedSPIString([
        0xF8, 0xD4, 0xC2, 0xD3, 0xE8, 0xC5, 0xD4, 0xC4, 0xD2, 0xD5, 0xC2, 0xC3,
        0xEE, 0xC9, 0xD4, 0xC2, 0xD3, 0xD4, 0x9D
    ])
    // Original: _setObscuredInsetsInternal:
    static let setObscuredInsetsInternal = decodedSPIString([
        0xF8, 0xD4, 0xC2, 0xD3, 0xE8, 0xC5, 0xD4, 0xC4, 0xD2, 0xD5, 0xC2, 0xC3,
        0xEE, 0xC9, 0xD4, 0xC2, 0xD3, 0xD4, 0xEE, 0xC9, 0xD3, 0xC2, 0xD5, 0xC9,
        0xC6, 0xCB, 0x9D
    ])
    // Original: _overrideLayoutParametersWithMinimumLayoutSize:maximumUnobscuredSizeOverride:
    static let overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride = decodedSPIString([
        0xF8, 0xC8, 0xD1, 0xC2, 0xD5, 0xD5, 0xCE, 0xC3, 0xC2, 0xEB, 0xC6, 0xDE,
        0xC8, 0xD2, 0xD3, 0xF7, 0xC6, 0xD5, 0xC6, 0xCA, 0xC2, 0xD3, 0xC2, 0xD5,
        0xD4, 0xF0, 0xCE, 0xD3, 0xCF, 0xEA, 0xCE, 0xC9, 0xCE, 0xCA, 0xD2, 0xCA,
        0xEB, 0xC6, 0xDE, 0xC8, 0xD2, 0xD3, 0xF4, 0xCE, 0xDD, 0xC2, 0x9D, 0xCA,
        0xC6, 0xDF, 0xCE, 0xCA, 0xD2, 0xCA, 0xF2, 0xC9, 0xC8, 0xC5, 0xD4, 0xC4,
        0xD2, 0xD5, 0xC2, 0xC3, 0xF4, 0xCE, 0xDD, 0xC2, 0xE8, 0xD1, 0xC2, 0xD5,
        0xD5, 0xCE, 0xC3, 0xC2, 0x9D
    ])
    // Original: _overrideLayoutParametersWithMinimumLayoutSize:minimumUnobscuredSizeOverride:maximumUnobscuredSizeOverride:
    static let overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride = decodedSPIString([
        0xF8, 0xC8, 0xD1, 0xC2, 0xD5, 0xD5, 0xCE, 0xC3, 0xC2, 0xEB, 0xC6, 0xDE,
        0xC8, 0xD2, 0xD3, 0xF7, 0xC6, 0xD5, 0xC6, 0xCA, 0xC2, 0xD3, 0xC2, 0xD5,
        0xD4, 0xF0, 0xCE, 0xD3, 0xCF, 0xEA, 0xCE, 0xC9, 0xCE, 0xCA, 0xD2, 0xCA,
        0xEB, 0xC6, 0xDE, 0xC8, 0xD2, 0xD3, 0xF4, 0xCE, 0xDD, 0xC2, 0x9D, 0xCA,
        0xCE, 0xC9, 0xCE, 0xCA, 0xD2, 0xCA, 0xF2, 0xC9, 0xC8, 0xC5, 0xD4, 0xC4,
        0xD2, 0xD5, 0xC2, 0xC3, 0xF4, 0xCE, 0xDD, 0xC2, 0xE8, 0xD1, 0xC2, 0xD5,
        0xD5, 0xCE, 0xC3, 0xC2, 0x9D, 0xCA, 0xC6, 0xDF, 0xCE, 0xCA, 0xD2, 0xCA,
        0xF2, 0xC9, 0xC8, 0xC5, 0xD4, 0xC4, 0xD2, 0xD5, 0xC2, 0xC3, 0xF4, 0xCE,
        0xDD, 0xC2, 0xE8, 0xD1, 0xC2, 0xD5, 0xD5, 0xCE, 0xC3, 0xC2, 0x9D
    ])
    // Original: _clearOverrideLayoutParameters
    static let clearOverrideLayoutParameters = decodedSPIString([
        0xF8, 0xC4, 0xCB, 0xC2, 0xC6, 0xD5, 0xE8, 0xD1, 0xC2, 0xD5, 0xD5, 0xCE,
        0xC3, 0xC2, 0xEB, 0xC6, 0xDE, 0xC8, 0xD2, 0xD3, 0xF7, 0xC6, 0xD5, 0xC6,
        0xCA, 0xC2, 0xD3, 0xC2, 0xD5, 0xD4
    ])
    // Original: _scrollViewSystemContentInset
    static let scrollViewSystemContentInset = decodedSPIString([
        0xF8, 0xD4, 0xC4, 0xD5, 0xC8, 0xCB, 0xCB, 0xF1, 0xCE, 0xC2, 0xD0, 0xF4,
        0xDE, 0xD4, 0xD3, 0xC2, 0xCA, 0xE4, 0xC8, 0xC9, 0xD3, 0xC2, 0xC9, 0xD3,
        0xEE, 0xC9, 0xD4, 0xC2, 0xD3
    ])
    // Original: _systemContentInset
    static let systemContentInset = decodedSPIString([
        0xF8, 0xD4, 0xDE, 0xD4, 0xD3, 0xC2, 0xCA, 0xE4, 0xC8, 0xC9, 0xD3, 0xC2,
        0xC9, 0xD3, 0xEE, 0xC9, 0xD4, 0xC2, 0xD3
    ])
    // Original: _frameOrBoundsMayHaveChanged
    static let frameOrBoundsMayHaveChanged = decodedSPIString([
        0xF8, 0xC1, 0xD5, 0xC6, 0xCA, 0xC2, 0xE8, 0xD5, 0xE5, 0xC8, 0xD2, 0xC9,
        0xC3, 0xD4, 0xEA, 0xC6, 0xDE, 0xEF, 0xC6, 0xD1, 0xC2, 0xE4, 0xCF, 0xC6,
        0xC9, 0xC0, 0xC2, 0xC3
    ])
    // Original: _inputViewBoundsInWindow
    static let inputViewBoundsInWindow = decodedSPIString([
        0xF8, 0xCE, 0xC9, 0xD7, 0xD2, 0xD3, 0xF1, 0xCE, 0xC2, 0xD0, 0xE5, 0xC8,
        0xD2, 0xC9, 0xC3, 0xD4, 0xEE, 0xC9, 0xF0, 0xCE, 0xC9, 0xC3, 0xC8, 0xD0
    ])
    // Original: _shouldDeferGeometryUpdates
    static let shouldDeferGeometryUpdates = decodedSPIString([
        0xF8, 0xD4, 0xCF, 0xC8, 0xD2, 0xCB, 0xC3, 0xE3, 0xC2, 0xC1, 0xC2, 0xD5,
        0xE0, 0xC2, 0xC8, 0xCA, 0xC2, 0xD3, 0xD5, 0xDE, 0xF2, 0xD7, 0xC3, 0xC6,
        0xD3, 0xC2, 0xD4
    ])
    // Original: _didStopDeferringGeometryUpdates
    static let didStopDeferringGeometryUpdates = decodedSPIString([
        0xF8, 0xC3, 0xCE, 0xC3, 0xF4, 0xD3, 0xC8, 0xD7, 0xE3, 0xC2, 0xC1, 0xC2,
        0xD5, 0xD5, 0xCE, 0xC9, 0xC0, 0xE0, 0xC2, 0xC8, 0xCA, 0xC2, 0xD3, 0xD5,
        0xDE, 0xF2, 0xD7, 0xC3, 0xC6, 0xD3, 0xC2, 0xD4
    ])
    // Original: _apiObject
    static let apiObject = decodedSPIString([
        0xF8, 0xC6, 0xD7, 0xCE, 0xE8, 0xC5, 0xCD, 0xC2, 0xC4, 0xD3
    ])
    // Original: _pageForTesting
    static let pageForTesting = decodedSPIString([
        0xF8, 0xD7, 0xC6, 0xC0, 0xC2, 0xE1, 0xC8, 0xD5, 0xF3, 0xC2, 0xD4, 0xD3,
        0xCE, 0xC9, 0xC0
    ])
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
    static let shouldDeferGeometryUpdates = ViewportSPIMethod(
        ViewportSPISelectorNames.shouldDeferGeometryUpdates, as: (() -> Bool).self
    )
    static let apiObject = ViewportSPIMethod(
        ViewportSPISelectorNames.apiObject, as: (() -> UnsafeRawPointer).self
    )
    static let pageForTesting = ViewportSPIMethod(
        ViewportSPISelectorNames.pageForTesting, as: (() -> UnsafeRawPointer?).self
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

    func invoke(on object: AnyObject, _ arguments: repeat each Argument) throws -> Result? {
        let receiverClass = object_getClass(object)!
        let key = ObjectIdentifier(receiverClass)
        let method: NativeObjCMethod<Result, repeat each Argument>
        if let cached = methods[key] {
            method = cached
        } else {
            do {
                method = try ABIRuntime.shared.object(object).resolveAndWait(
                    .objc(.method(selector, as: signature))
                ).method
            } catch ABIResolutionError.declarationNotFound {
                return nil
            }
            methods[key] = method
        }
        return try unsafe method.unsafeInvoke(on: object, repeat each arguments)
    }
}

@MainActor
private final class ViewportPageSizeMethod {
    private let declaration: String
    private var method: NativeCXXMethod<Void, UnsafeRawPointer>?

    init(_ declaration: String) {
        self.declaration = declaration
    }

    func invoke(_ size: CGSize, on webView: NSObject) throws -> Bool {
        guard let pageResult = try ViewportSPIMethods.pageForTesting.invoke(on: webView),
              let wrapperAddress = pageResult else { return false }
        let wrapper = Unmanaged<AnyObject>.fromOpaque(wrapperAddress).takeUnretainedValue()
        guard let page = try ViewportSPIMethods.apiObject.invoke(on: wrapper) else { return false }
        let storage = unsafe NativeValue(
            borrowing: UnsafeMutableRawPointer(mutating: page),
            as: try .opaque(named: ViewportPageSizeMethods.pageTypeName),
            retaining: webView
        )
        let prepared: NativeCXXMethod<Void, UnsafeRawPointer>
        if let method {
            prepared = method
        } else {
            prepared = try ABIRuntime.shared.cxxObject(
                storage, typeNamed: ViewportPageSizeMethods.pageTypeName, in: .framework(named: "WebKit")
            ).resolveAndWait(.cxx(.method(declaration, as: ((UnsafeRawPointer) -> Void).self))).method
            method = prepared
        }
        // WebCore::FloatSize stores two floats; pass its address for const&.
        let nativeSize = SIMD2<Float>(Float(size.width), Float(size.height))
        try withUnsafePointer(to: nativeSize) { pointer in
            try unsafe prepared.unsafeInvoke(on: storage, UnsafeRawPointer(pointer))
        }
        return true
    }
}

@MainActor
private enum ViewportPageSizeMethods {
    // Original: WebKit::WebPageProxy
    static let pageTypeName = decodedSPIString([
        0xF0, 0xC2, 0xC5, 0xEC, 0xCE, 0xD3, 0x9D, 0x9D, 0xF0, 0xC2, 0xC5, 0xF7,
        0xC6, 0xC0, 0xC2, 0xF7, 0xD5, 0xC8, 0xDF, 0xDE
    ])
    // Original: setDefaultUnobscuredSize(WebCore::FloatSize const&)
    static let defaultSize = ViewportPageSizeMethod(
        decodedSPIString([
            0xD4, 0xC2, 0xD3, 0xE3, 0xC2, 0xC1, 0xC6, 0xD2, 0xCB, 0xD3, 0xF2, 0xC9,
            0xC8, 0xC5, 0xD4, 0xC4, 0xD2, 0xD5, 0xC2, 0xC3, 0xF4, 0xCE, 0xDD, 0xC2,
            0x8F, 0xF0, 0xC2, 0xC5, 0xE4, 0xC8, 0xD5, 0xC2, 0x9D, 0x9D, 0xE1, 0xCB,
            0xC8, 0xC6, 0xD3, 0xF4, 0xCE, 0xDD, 0xC2, 0x87, 0xC4, 0xC8, 0xC9, 0xD4,
            0xD3, 0x81, 0x8E
        ])
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
    @available(iOS 26.0, *)
    static func coordinateDefaultViewportSize(
        in webView: WKWebView,
        whileActive isActive: @escaping @MainActor () -> Bool
    ) -> [NativeObjCMethodHook] {
        let hookLogger = logger
        // WebKit restores default viewport units on every layout and after
        // animated resizing. Follow both native recalculation boundaries.
        return [
            ViewportSPISelectorNames.frameOrBoundsMayHaveChanged,
            ViewportSPISelectorNames.didStopDeferringGeometryUpdates
        ].compactMap { selector in
            perform {
                try unsafe ABIRuntime.shared.object(webView).hookMainActorCalls(
                    .objc(.method(selector, as: (() -> Void).self)),
                    onFailure: { error in
                        hookLogger.error("Viewport layout hook failed: \(String(describing: error), privacy: .public)")
                    }
                ) { [weak webView] call in
                    try call.proceed()
                    // A deferred presentation callback can invalidate the
                    // coordinator while the native continuation is running.
                    if isActive(), let webView, webView.window != nil {
                        applyDefaultViewportSize(to: webView)
                    }
                }
            }
        }
    }

    @available(iOS 26.0, *)
    @discardableResult
    static func applyDefaultViewportSize(to webView: WKWebView) -> Bool {
        // The full layout override also freezes public viewport-inset updates
        // and ties vh to lvh. Change only the default viewport width instead.
        perform {
            if try ViewportSPIMethods.shouldDeferGeometryUpdates.invoke(on: webView) == true {
                return true
            }
            // The explicit obscured insets already reflect the selected edges.
            // System scroll insets can still include edges excluded from layout.
            let layout = webView.bounds.inset(by: webView.obscuredContentInsets)
            return try ViewportPageSizeMethods.defaultSize.invoke(
                CGSize(width: max(0, layout.width), height: webView.bounds.height), on: webView
            )
        } ?? false
    }

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

    @available(iOS 26.0, *)
    static func restoreDefaultViewportSize(on webView: WKWebView) {
        frameOrBoundsMayHaveChanged(on: webView)
        // Native geometry recalculation can be deferred during a resize. Release
        // this coordinator's default-size contribution even in that interval.
        _ = perform { try ViewportPageSizeMethods.defaultSize.invoke(webView.bounds.size, on: webView) }
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
