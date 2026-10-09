#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import WebKit
import XCTest
@testable import WKViewportCoordinator

@Suite(.serialized)
@MainActor
struct ViewportCoordinatorTests {
    @Test(arguments: [false, true])
    func verticalTabBarObscuresItsOwnEdge(isLeading: Bool) {
        let windowInsets = UIEdgeInsets(top: 0, left: isLeading ? 80 : 0, bottom: 30, right: isLeading ? 0 : 80)
        let geometry = ViewportGeometry(
            bounds: CGRect(x: 0, y: 0, width: 480, height: 680),
            windowSafeAreaInsets: windowInsets,
            safeAreaInsets: windowInsets,
            navigationBarFrame: nil,
            barFrames: [CGRect(x: isLeading ? 0 : 410, y: 0, width: 70, height: 680)]
        )
        let insets = geometry.obscuredInsets(includesNavigationBar: true)
        #expect(insets.bottom == 30)
        #expect(insets.top == 0)
        #expect(insets.left == (isLeading ? 80 : 0))
        #expect(insets.right == (isLeading ? 0 : 80))
    }

    @Test
    func horizontalInsetsKeepWebContentInsideWindowAndContainerSafeAreas() {
        let windowInsets = UIEdgeInsets(top: 0, left: 44, bottom: 20, right: 24)
        var geometry = ViewportGeometry(
            bounds: CGRect(x: 0, y: 0, width: 900, height: 420),
            windowSafeAreaInsets: windowInsets,
            safeAreaInsets: windowInsets,
            navigationBarFrame: nil,
            barFrames: []
        )
        for inspectorWidth: CGFloat in [0, 300, 0, 240] {
            geometry.safeAreaInsets.right = max(windowInsets.right, inspectorWidth)
            let insets = geometry.obscuredInsets(includesNavigationBar: true)
            #expect(insets.left == 44)
            #expect(insets.right == max(24, inspectorWidth))
            let resolved = ResolvedViewportMetrics(
                state: ViewportMetrics(
                    safeArea: .init(viewport: windowInsets, legacyFallbackBaseline: geometry.safeAreaInsets),
                    obscuredInsets: insets,
                    keyboardOverlapHeight: 0,
                    inputAccessoryOverlapHeight: 0
                ),
                contentInsetAdjustmentBehavior: .never,
                screenScale: 3
            )
            #expect(resolved.unobscuredSafeAreaInsets == .zero)
            #expect(resolved.legacyLayoutViewportSize(in: geometry.bounds).width == 900 - 44 - max(24, inspectorWidth))
        }
    }

    @Test
    func narrowViewportDoesNotReclassifyAHorizontalBar() {
        let geometry = ViewportGeometry(
            bounds: CGRect(x: 200, y: 0, width: 40, height: 600),
            windowSafeAreaInsets: .zero,
            safeAreaInsets: .zero,
            navigationBarFrame: nil,
            barFrames: [CGRect(x: 0, y: 550, width: 400, height: 50)]
        )
        #expect(geometry.obscuredInsets(includesNavigationBar: true) == UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0))
    }

    @Test
    func viewportMetricsUseWebViewBoundsWhenItsFrameDoesNotFillItsParent() {
        let controller = UIViewController()
        let window = makeWindow(rootViewController: controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        let webView = WKWebView(frame: controller.view.bounds.insetBy(dx: 100, dy: 100))
        controller.view.addSubview(webView)
        controller.view.layoutIfNeeded()
        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: controller, webView: webView, keyboardOverlapHeight: 0, inputAccessoryOverlapHeight: 0
        )
        #expect(metrics.safeArea.viewport == .zero)
        #expect(metrics.obscuredInsets == .zero)
    }

    @Test
    @available(iOS 26.0, *)
    func refreshInsetSurvivesViewportUpdatesAndInvalidation() throws {
        let controller = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: controller.view)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let window = makeWindow(rootViewController: controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        let coordinator = ViewportCoordinator(webView: webView)
        let baseline = webView.scrollView.contentInset
        // Model the inset UIRefreshControl owns between valueChanged and endRefreshing.
        webView.scrollView.contentInset.top += 60
        coordinator.handleObservedWebViewStateChangeForTesting()
        #expect(webView.scrollView.contentInset.top == baseline.top + 60)
        coordinator.additionalObscuredContentInsets = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 200)
        #expect(webView.scrollView.contentInset.top == baseline.top + 72)
        #expect(webView.scrollView.contentInset.right == baseline.right + 200)
        coordinator.invalidate()
        #expect(webView.scrollView.contentInset == UIEdgeInsets(top: 60, left: 0, bottom: 0, right: 0))
        webView.scrollView.contentInset.top -= 60
        #expect(webView.scrollView.contentInset == .zero)
    }

    @Test
    func resolvedMetricsRoundInsetsToPixelBoundaries() {
        let first = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 58.97, left: 0, bottom: 34.02, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 58.97, left: 0, bottom: 34.02, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 102.98, left: 0, bottom: 87.96, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let second = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59.01, left: 0, bottom: 34.04, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59.01, left: 0, bottom: 34.04, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103.01, left: 0, bottom: 87.99, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(first == second)
        #expect(first.obscuredInsets.top == 103)
        #expect(first.obscuredInsets.bottom == 88)
    }

    @Test
    func viewportMetricsResolverUsesProjectedWindowSafeAreaWhenNoChromeOverlaps() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)
        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = window.bounds
        hostViewController.view.layoutIfNeeded()
        window.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: hostView))
        #expect(metrics.safeArea.legacyFallbackBaseline == hostView.safeAreaInsets)
        #expect(metrics.obscuredInsets.top == metrics.safeArea.viewport.top)
        #expect(metrics.obscuredInsets.bottom == metrics.safeArea.viewport.bottom)
    }

    @Test
    func viewportMetricsResolverIncludesVisibleNavigationBarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setNavigationBarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = window.bounds
        hostViewController.view.layoutIfNeeded()
        navigationController.view.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        let hostView = try #require(webView.superview)
        let barFrame = navigationController.navigationBar.convert(navigationController.navigationBar.bounds, to: hostView)
        #expect(barFrame.maxY > hostView.bounds.minY)
        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: hostView))
        #expect(metrics.obscuredInsets.top == max(metrics.safeArea.viewport.top, barFrame.maxY - hostView.bounds.minY))
    }

    @Test(arguments: [(CGFloat(0), CGFloat(0)), (CGFloat(300), CGFloat(344))])
    func excludingNavigationBarPreservesSafeAreaAndBottomObscuration(
        keyboardHeight: CGFloat,
        accessoryHeight: CGFloat
    ) throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)
        let navigationController = UINavigationController(rootViewController: hostViewController)
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([navigationController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = window.bounds
        hostViewController.view.layoutIfNeeded()
        let resolver = ViewportMetricsResolver()
        let included = resolver.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: keyboardHeight,
            inputAccessoryOverlapHeight: accessoryHeight
        )
        let excluded = resolver.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: keyboardHeight,
            inputAccessoryOverlapHeight: accessoryHeight,
            includesNavigationBar: false
        )

        #expect(included.obscuredInsets.top > included.safeArea.viewport.top)
        let barFrame = webView.convert(navigationController.navigationBar.bounds, from: navigationController.navigationBar)
        #expect(included.obscuredInsets.top - excluded.obscuredInsets.top == webView.bounds.intersection(barFrame).height)
        #expect(excluded.safeArea == included.safeArea)
        #expect(excluded.obscuredInsets.bottom == included.obscuredInsets.bottom)
        #expect(excluded.obscuredInsets.bottom > excluded.safeArea.viewport.bottom)
        #expect(excluded.keyboardOverlapHeight == keyboardHeight)
        #expect(excluded.inputAccessoryOverlapHeight == accessoryHeight)
        #expect(excluded.finalObscuredInsets.bottom == included.finalObscuredInsets.bottom)
    }

    @Test
    @available(iOS 26.0, *)
    func navigationBarObscurationCanChangeWithoutChangingOtherViewportOptions() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = window.bounds
        hostViewController.view.layoutIfNeeded()
        let coordinator = ViewportCoordinator(webView: webView, hostViewController: hostViewController)
        defer { coordinator.invalidate() }
        coordinator.additionalObscuredContentInsets = UIEdgeInsets(top: 7, left: 3, bottom: 11, right: 5)
        webView.scrollView.topEdgeEffect.isHidden = true
        webView.scrollView.topEdgeEffect.style = .hard
        webView.scrollView.bottomEdgeEffect.isHidden = false
        webView.scrollView.bottomEdgeEffect.style = .soft
        let included = try #require(coordinator.resolvedMetricsForTesting)
        #expect(coordinator.includesNavigationBar)
        #expect(included.obscuredInsets.top > included.viewportSafeAreaInsets.top + 7)

        coordinator.includesNavigationBar = false
        let excluded = try #require(coordinator.resolvedMetricsForTesting)
        let barFrame = webView.convert(navigationController.navigationBar.bounds, from: navigationController.navigationBar)
        #expect(included.obscuredInsets.top - excluded.obscuredInsets.top == webView.bounds.intersection(barFrame).height)
        #expect(webView.obscuredContentInsets == excluded.obscuredInsets)
        #expect(webView.scrollView.contentInset == excluded.obscuredInsets)
        #expect(webView.scrollView.adjustedContentInset == excluded.obscuredInsets)
        #expect(excluded.obscuredInsets.left == included.obscuredInsets.left)
        #expect(excluded.obscuredInsets.bottom == included.obscuredInsets.bottom)
        #expect(excluded.obscuredInsets.right == included.obscuredInsets.right)

        for hidden in [true, false] {
            navigationController.setNavigationBarHidden(hidden, animated: false)
            navigationController.view.layoutIfNeeded()
            hostViewController.view.layoutIfNeeded()
            coordinator.update()
            let updated = try #require(coordinator.resolvedMetricsForTesting)
            let expectedTop = hidden ? updated.viewportSafeAreaInsets.top + 7 : excluded.obscuredInsets.top
            #expect(updated.obscuredInsets.top == expectedTop)
            #expect(webView.obscuredContentInsets.top == expectedTop)
            #expect(webView.scrollView.adjustedContentInset.top == expectedTop)
        }

        coordinator.includesNavigationBar = true
        let restored = try #require(coordinator.resolvedMetricsForTesting)
        #expect(restored.obscuredInsets == included.obscuredInsets)
        #expect(webView.scrollView.contentInsetAdjustmentBehavior == .never)
        #expect(webView.scrollView.topEdgeEffect.isHidden)
        #expect(webView.scrollView.topEdgeEffect.style == .hard)
        #expect(webView.scrollView.bottomEdgeEffect.isHidden == false)
        #expect(webView.scrollView.bottomEdgeEffect.style == .soft)
    }

    @Test
    func navigationBarExclusionPreservesTheAreaAboveTheBar() {
        let geometry = ViewportGeometry(
            bounds: CGRect(x: 0, y: 0, width: 400, height: 600),
            windowSafeAreaInsets: .zero,
            safeAreaInsets: UIEdgeInsets(top: 84, left: 0, bottom: 0, right: 0),
            navigationBarFrame: CGRect(x: 0, y: 24, width: 400, height: 60),
            barFrames: []
        )
        #expect(geometry.obscuredInsets(includesNavigationBar: true).top == 84)
        #expect(geometry.obscuredInsets(includesNavigationBar: false).top == 24)
    }

    @Test(arguments: [
        CGRect(x: 0, y: -54, width: 100, height: 54),
        CGRect(x: 0, y: 200, width: 100, height: 54),
        CGRect(x: 100, y: 24, width: 100, height: 54),
    ])
    func geometryIgnoresNavigationBarOutsideViewport(barFrame: CGRect) {
        let geometry = ViewportGeometry(
            bounds: CGRect(x: 0, y: 0, width: 100, height: 200),
            windowSafeAreaInsets: .zero,
            safeAreaInsets: .zero,
            navigationBarFrame: barFrame,
            barFrames: []
        )
        #expect(geometry.obscuredInsets(includesNavigationBar: true) == .zero)
    }

    @Test
    func viewportMetricsResolverIncludesVisibleTabBarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([hostViewController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = tabBarController.view.bounds
        hostViewController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: try #require(webView.superview)))
        #expect(
            metrics.obscuredInsets.bottom
                == max(
                    metrics.safeArea.viewport.bottom,
                    bottomEdgeObscuredHeight(of: tabBarController.tabBar, in: try #require(webView.superview))
                )
        )
    }

    @Test
    func viewportMetricsResolverIncludesVisibleToolbarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setToolbarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = window.bounds
        hostViewController.view.layoutIfNeeded()
        navigationController.view.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)
        let bottomObscuredHeight = bottomEdgeObscuredHeight(
            of: [navigationController.toolbar],
            in: hostView,
            extendingFrom: metrics.safeArea.viewport.bottom
        )

        #expect(
            metrics.obscuredInsets.bottom == bottomObscuredHeight
        )
    }

    @Test(arguments: [false, true])
    func stackedBarsExtendTheBottomSafeAreaInEitherOrder(reversed: Bool) {
        let tabBar = CGRect(x: 0, y: 530, width: 400, height: 50)
        let toolbar = CGRect(x: 0, y: 490, width: 400, height: 40)
        let geometry = ViewportGeometry(
            bounds: CGRect(x: 0, y: 0, width: 400, height: 600),
            windowSafeAreaInsets: UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0),
            navigationBarFrame: nil,
            barFrames: reversed ? [toolbar, tabBar] : [tabBar, toolbar]
        )
        #expect(geometry.obscuredInsets(includesNavigationBar: true).bottom == 110)
    }

    @Test
    func viewportMetricsResolverIgnoresHiddenTabBarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([hostViewController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        tabBarController.setTabBarHidden(true, animated: false)
        hostViewController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: try #require(webView.superview)))
        #expect(metrics.obscuredInsets.bottom == metrics.safeArea.viewport.bottom)
    }

    @Test
    func detachedFloatingBarDoesNotObscureAnEntireEdge() {
        let geometry = ViewportGeometry(
            bounds: CGRect(x: 0, y: 0, width: 400, height: 600),
            windowSafeAreaInsets: UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0),
            safeAreaInsets: UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0),
            navigationBarFrame: nil,
            barFrames: [CGRect(x: 20, y: 500, width: 360, height: 50)]
        )
        #expect(geometry.obscuredInsets(includesNavigationBar: true).bottom == 20)
    }

    @Test
    func viewportMetricsResolverSeparatesViewportAndLegacyFallbackSafeAreas() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([hostViewController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let resolver = ViewportMetricsResolver()
        let baseline = resolver.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        hostViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 16, left: 0, bottom: 48, right: 0)
        hostViewController.view.setNeedsLayout()
        hostViewController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let updated = resolver.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(updated.safeArea.viewport == baseline.safeArea.viewport)
        #expect(updated.safeArea.legacyFallbackBaseline == hostViewController.view.safeAreaInsets)
        #expect(updated.safeArea.legacyFallbackBaseline != baseline.safeArea.legacyFallbackBaseline)
        #expect(updated.obscuredInsets.top == baseline.obscuredInsets.top + 16)
        #expect(updated.obscuredInsets.bottom == baseline.obscuredInsets.bottom + 48)
    }

    @Test
    func viewportMetricsResolverProjectsWindowSafeAreaIntoContainerSubview() throws {
        let rootViewController = UIViewController()
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.loadViewIfNeeded()
        rootViewController.addChild(hostViewController)
        rootViewController.view.addSubview(hostViewController.view)
        hostViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostViewController.view.topAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.topAnchor),
            hostViewController.view.leadingAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.leadingAnchor),
            hostViewController.view.trailingAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.trailingAnchor),
            hostViewController.view.bottomAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        hostViewController.didMove(toParent: rootViewController)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: rootViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        rootViewController.view.layoutIfNeeded()
        hostViewController.view.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: hostView))
        #expect(metrics.safeArea.legacyFallbackBaseline == hostView.safeAreaInsets)
        #expect(metrics.obscuredInsets.top == 0)
        #expect(metrics.obscuredInsets.bottom == 0)
    }

    @Test
    func viewportMetricsResolverUsesWebViewSuperviewWhenSwiftUIInsetsViewport() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let viewportContainer = UIView()
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(viewportContainer)
        NSLayoutConstraint.activate([
            viewportContainer.topAnchor.constraint(equalTo: hostViewController.view.safeAreaLayoutGuide.topAnchor),
            viewportContainer.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            viewportContainer.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            viewportContainer.bottomAnchor.constraint(equalTo: hostViewController.view.safeAreaLayoutGuide.bottomAnchor),
        ])
        attach(webView, to: viewportContainer)

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setNavigationBarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.layoutIfNeeded()
        navigationController.view.layoutIfNeeded()

        let metrics = ViewportMetricsResolver().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: viewportContainer))
        #expect(metrics.safeArea.legacyFallbackBaseline == viewportContainer.safeAreaInsets)
        #expect(metrics.obscuredInsets.top == 0)
    }

    @Test
    func coordinatorInstallsObservationViewWhenHostViewLoadsAfterInitialization() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let coordinator = ViewportCoordinator(webView: webView, hostViewController: hostViewController)
        #expect(coordinator.hasObservationViewForTesting == false)

        webView.translatesAutoresizingMaskIntoConstraints = false
        attach(webView, to: hostViewController.view)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setToolbarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        coordinator.update()

        #expect(coordinator.hasObservationViewForTesting == true)
        #expect(coordinator.observationSuperviewForTesting === hostViewController.view)
        #expect(coordinator.resolvedMetricsForTesting != nil)
    }

    @Test
    func coordinatorResolvesHostViewControllerFromResponderChain() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        attach(webView, to: hostViewController.view)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setToolbarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)

        #expect(coordinator.resolvedHostViewControllerForTesting === hostViewController)
        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        coordinator.invalidate()
    }

    @Test
    func coordinatorRegistersHostedScrollViewForNavigationChrome() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        attach(webView, to: hostViewController.view)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setToolbarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)

        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        #expect(hostViewController.contentScrollView(for: .bottom) === webView.scrollView)
        coordinator.invalidate()
        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(hostViewController.contentScrollView(for: .bottom) == nil)
    }

    @Test
    func coordinatorReadsScrollViewAdjustmentBehaviorWithoutChangingIt() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let resolvedMetrics = try #require(coordinator.resolvedMetricsForTesting)

        #expect(webView.scrollView.contentInsetAdjustmentBehavior == .never)
        #expect(resolvedMetrics.contentInsetAdjustmentBehavior == .never)
        #expect(resolvedMetrics.contentScrollInsetFallback == resolvedMetrics.obscuredInsets)
        coordinator.invalidate()
        #expect(webView.scrollView.contentInsetAdjustmentBehavior == .never)
    }

    @Test
    @available(iOS 26.0, *)
    func modernNeverInsetsAreReleasedWhenAutomaticAdjustmentResumes() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        let customInset = UIEdgeInsets(top: 9, left: 3, bottom: 7, right: 5)
        webView.scrollView.contentInset = customInset
        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let automaticCoordinator = ViewportCoordinator(webView: webView)
        #expect(webView.scrollView.contentInset == customInset)
        automaticCoordinator.invalidate()
        #expect(webView.scrollView.contentInset == customInset)

        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let coordinator = ViewportCoordinator(webView: webView)
        coordinator.additionalObscuredContentInsets.top = 12
        let managedInset = try #require(coordinator.resolvedMetricsForTesting).obscuredInsets
        #expect(managedInset.top > 0)
        let combinedInset = UIEdgeInsets(
            top: customInset.top + managedInset.top,
            left: customInset.left + managedInset.left,
            bottom: customInset.bottom + managedInset.bottom,
            right: customInset.right + managedInset.right
        )
        #expect(webView.scrollView.contentInset == combinedInset)
        #expect(webView.scrollView.adjustedContentInset == combinedInset)

        webView.scrollView.contentInsetAdjustmentBehavior = .always
        coordinator.update()
        #expect(webView.scrollView.contentInset == customInset)
        #expect(webView.scrollView.contentInsetAdjustmentBehavior == .always)

        webView.scrollView.contentInset = customInset
        coordinator.invalidate()
        #expect(webView.scrollView.contentInset == customInset)
    }

    @Test(arguments: [false, true])
    @available(iOS 26.0, *)
    func modernNeverInsetsSurviveDetachmentAndResetOnInvalidate(changeAdjustmentWhileDetached: Bool) throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let constraints = attach(webView, to: hostViewController.view)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        coordinator.additionalObscuredContentInsets.top = 12
        let managedInset = try #require(coordinator.resolvedMetricsForTesting).obscuredInsets
        #expect(managedInset.top > 0)
        NSLayoutConstraint.deactivate(constraints)
        let orphanContainer = UIView()
        attach(webView, to: orphanContainer)
        coordinator.update()
        if changeAdjustmentWhileDetached {
            webView.scrollView.contentInsetAdjustmentBehavior = .always
            coordinator.update()
        }
        #expect(webView.scrollView.contentInset == managedInset)
        #expect(webView.obscuredContentInsets == managedInset)

        coordinator.invalidate()
        #expect(webView.scrollView.contentInset == .zero)
        #expect(webView.obscuredContentInsets == .zero)
    }

    @Test
    @available(iOS 26.0, *)
    func modernNeverInsetsFollowKeyboardAndAccessoryGeometry() throws {
        let hostViewController = UIViewController()
        let webView = InputAccessoryReportingWebView(frame: .zero)
        attach(webView, to: hostViewController.view)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        defer { coordinator.invalidate() }
        let baseline = webView.scrollView.contentInset
        let keyboardFrame = window.convert(
            CGRect(x: 0, y: window.bounds.maxY - 260, width: window.bounds.width, height: 260),
            to: window.screen.coordinateSpace
        )
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboardFrame)]
        )
        #expect(webView.obscuredContentInsets.bottom == 260)
        #expect(webView.scrollView.contentInset == webView.obscuredContentInsets)

        webView.reportedInputViewBoundsInWindow = CGRect(
            x: 0, y: window.bounds.maxY - 304, width: window.bounds.width, height: 304
        )
        coordinator.update()
        #expect(webView.obscuredContentInsets.bottom == 304)
        #expect(webView.scrollView.contentInset == webView.obscuredContentInsets)

        webView.reportedInputViewBoundsInWindow = .null
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillHideNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboardFrame)]
        )
        #expect(webView.scrollView.contentInset == baseline)
        #expect(webView.scrollView.contentInset == webView.obscuredContentInsets)
    }

    @Test
    func coordinatorRefreshesWhenScrollViewAdjustmentBehaviorChanges() async throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let initialMetrics = try #require(coordinator.resolvedMetricsForTesting)
        #expect(initialMetrics.contentInsetAdjustmentBehavior != .never)

        let update = XCTKVOExpectation(
            keyPath: #keyPath(ViewportCoordinator.appliedViewportUpdateCountForTesting),
            object: coordinator
        )
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let result = await XCTWaiter.fulfillment(of: [update], timeout: 10)
        try #require(result == .completed)

        let updatedMetrics = try #require(coordinator.resolvedMetricsForTesting)
        #expect(updatedMetrics.contentInsetAdjustmentBehavior == .never)
        #expect(updatedMetrics.contentScrollInsetFallback.top == updatedMetrics.obscuredInsets.top)
        #expect(updatedMetrics.contentScrollInsetFallback.left == updatedMetrics.obscuredInsets.left)
        #expect(updatedMetrics.contentScrollInsetFallback.right == updatedMetrics.obscuredInsets.right)
        #expect(updatedMetrics.contentScrollInsetFallback.bottom <= updatedMetrics.obscuredInsets.bottom)
        coordinator.invalidate()
    }

    @Test
    func registeredContentScrollViewUsesRootHostSafeAreaWhenAttachedDirectly() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setNavigationBarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.layoutIfNeeded()
        navigationController.view.layoutIfNeeded()
        hostViewController.setContentScrollView(webView.scrollView)
        webView.scrollView.layoutIfNeeded()

        #expect(webView.scrollView.adjustedContentInset.top == hostViewController.view.safeAreaInsets.top)
    }

    @Test
    func registeredContentScrollViewUsesContainerSafeAreaWhenEmbedded() {
        let hostViewController = UIViewController()
        let viewportContainer = UIView()
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(viewportContainer)
        NSLayoutConstraint.activate([
            viewportContainer.topAnchor.constraint(equalTo: hostViewController.view.safeAreaLayoutGuide.topAnchor),
            viewportContainer.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            viewportContainer.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            viewportContainer.bottomAnchor.constraint(equalTo: hostViewController.view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let webView = WKWebView(frame: .zero)
        attach(webView, to: viewportContainer)

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setNavigationBarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.layoutIfNeeded()
        navigationController.view.layoutIfNeeded()
        viewportContainer.layoutIfNeeded()
        hostViewController.setContentScrollView(webView.scrollView)
        webView.scrollView.layoutIfNeeded()

        #expect(viewportContainer.safeAreaInsets == .zero)
        #expect(webView.scrollView.adjustedContentInset == .zero)
    }

    @Test
    func coordinatorUsesSwiftUIContainerAsObservationSuperview() async throws {
        let webView = WKWebView(frame: .zero)
        let box = ContainerViewBox()
        let hostingController = UIHostingController(
            rootView: HostingWebViewContainer(webView: webView, box: box)
        )
        let window = makeWindow(rootViewController: hostingController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostingController.view.layoutIfNeeded()
        let result = await XCTWaiter.fulfillment(of: [box.attachedToWindow], timeout: 10)
        try #require(result == .completed)

        let containerView = try #require(box.view)
        let coordinator = ViewportCoordinator(webView: webView)

        #expect(coordinator.resolvedHostViewControllerForTesting === hostingController)
        #expect(coordinator.observationSuperviewForTesting === containerView)
        #expect(coordinator.observationSuperviewForTesting !== hostingController.view)
        #expect(hostingController.contentScrollView(for: .top) === webView.scrollView)
        #expect(hostingController.contentScrollView(for: .bottom) === webView.scrollView)
        coordinator.invalidate()
    }

    @Test
    func coordinatorComputesKeyboardOverlapInContainerCoordinates() throws {
        let hostViewController = UIViewController()
        let viewportContainer = UIView()
        let webView = WKWebView(frame: .zero)
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(viewportContainer)
        NSLayoutConstraint.activate([
            viewportContainer.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            viewportContainer.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            viewportContainer.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            viewportContainer.heightAnchor.constraint(equalToConstant: 280)
        ])
        attach(webView, to: viewportContainer)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.layoutIfNeeded()
        let coordinator = ViewportCoordinator(webView: webView, hostViewController: hostViewController)
        let keyboardFrame = CGRect(
            x: 0,
            y: window.bounds.maxY - 200,
            width: window.bounds.width,
            height: 200
        )
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboardFrame)]
        )

        let resolvedMetrics = try #require(coordinator.resolvedMetricsForTesting)
        #expect(resolvedMetrics.obscuredInsets.bottom == 0)
        coordinator.invalidate()
    }

    @Test
    func coordinatorComputesInputAccessoryOverlapInContainerCoordinates() throws {
        let hostViewController = UIViewController()
        let viewportContainer = UIView()
        let webView = InputAccessoryReportingWebView(frame: .zero)
        viewportContainer.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(viewportContainer)
        NSLayoutConstraint.activate([
            viewportContainer.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            viewportContainer.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            viewportContainer.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            viewportContainer.heightAnchor.constraint(equalToConstant: 280)
        ])
        attach(webView, to: viewportContainer)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.layoutIfNeeded()
        webView.reportedInputViewBoundsInWindow = CGRect(
            x: 0,
            y: window.bounds.maxY - 120,
            width: window.bounds.width,
            height: 120
        )

        let coordinator = ViewportCoordinator(webView: webView, hostViewController: hostViewController)
        let resolvedMetrics = try #require(coordinator.resolvedMetricsForTesting)
        #expect(resolvedMetrics.obscuredInsets.bottom == 0)
        coordinator.invalidate()
    }

    @Test
    func coordinatorReusesObservationViewWhileSuperviewIsStable() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        attach(webView, to: hostViewController.view)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let firstObservationView = coordinator.observationViewForTesting
        let firstSuperview = coordinator.observationSuperviewForTesting

        coordinator.update()

        #expect(coordinator.observationViewForTesting === firstObservationView)
        #expect(coordinator.observationSuperviewForTesting === firstSuperview)
        coordinator.invalidate()
    }

    @Test
    func coordinatorRefreshesWhenSameHostViewControllerIsAssignedAgain() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView, hostViewController: hostViewController)
        let initialUpdateCount = coordinator.appliedViewportUpdateCountForTesting

        coordinator.hostViewController = hostViewController

        #expect(coordinator.appliedViewportUpdateCountForTesting == initialUpdateCount + 1)
        #expect(coordinator.resolvedHostViewControllerForTesting === hostViewController)
        coordinator.invalidate()
    }

    @Test
    func coordinatorMovesObservationViewWhenWebViewSuperviewChanges() {
        let hostViewController = UIViewController()
        let firstContainer = UIView()
        let secondContainer = UIView()
        let webView = WKWebView(frame: .zero)
        [firstContainer, secondContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            hostViewController.view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            firstContainer.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            firstContainer.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            firstContainer.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            firstContainer.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor),
            secondContainer.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            secondContainer.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            secondContainer.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            secondContainer.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor),
        ])

        let firstConstraints = attach(webView, to: firstContainer)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        #expect(coordinator.observationSuperviewForTesting === firstContainer)

        webView.removeFromSuperview()
        NSLayoutConstraint.deactivate(firstConstraints)
        attach(webView, to: secondContainer)
        hostViewController.view.layoutIfNeeded()
        coordinator.update()

        #expect(coordinator.observationSuperviewForTesting === secondContainer)
        coordinator.invalidate()
    }

    @Test
    func coordinatorClearsObservedScrollViewAndObservationWhenWebViewBecomesWindowless() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let hostedConstraints = attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)

        let orphanContainer = UIView()
        NSLayoutConstraint.deactivate(hostedConstraints)
        attach(webView, to: orphanContainer)
        coordinator.update()

        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(hostViewController.contentScrollView(for: .bottom) == nil)
        #expect(coordinator.observationSuperviewForTesting == nil)
        #expect(coordinator.resolvedMetricsForTesting != nil)
        coordinator.invalidate()
    }

    @Test
    func coordinatorReattachesHostedScrollViewAfterWindowlessTransition() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let hostedConstraints = attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let orphanContainer = UIView()
        NSLayoutConstraint.deactivate(hostedConstraints)
        webView.removeFromSuperview()
        let orphanConstraints = attach(webView, to: orphanContainer)
        coordinator.update()

        NSLayoutConstraint.deactivate(orphanConstraints)
        webView.removeFromSuperview()
        attach(webView, to: hostViewController.view)
        hostViewController.view.layoutIfNeeded()
        coordinator.update()

        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        #expect(hostViewController.contentScrollView(for: .bottom) === webView.scrollView)
        #expect(coordinator.observationSuperviewForTesting === hostViewController.view)
        coordinator.invalidate()
    }

    @Test
    func invalidationReleasesWebKitOverridesAndStopsFurtherUpdates() throws {
        let controller = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: controller.view)
        let window = makeWindow(rootViewController: controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        let coordinator = ViewportCoordinator(webView: webView)
        coordinator.additionalObscuredContentInsets.top = 12
        let selectors = ["_haveSetObscuredInsets", "_haveSetUnobscuredSafeAreaInsets"]
        for name in selectors {
            try #require(webView.responds(to: NSSelectorFromString(name)))
            #expect((webView.value(forKey: name) as? NSNumber)?.boolValue == true)
        }
        coordinator.invalidate()
        for name in selectors {
            #expect((webView.value(forKey: name) as? NSNumber)?.boolValue == false)
        }
        let updateCount = coordinator.appliedViewportUpdateCountForTesting
        coordinator.update()
        coordinator.hostViewController = controller
        coordinator.additionalObscuredContentInsets.top = 24
        coordinator.handleObservedWebViewStateChangeForTesting()
        #expect(coordinator.appliedViewportUpdateCountForTesting == updateCount)
        #expect(!coordinator.hasObservationViewForTesting)
        #expect(controller.contentScrollView(for: .top) == nil)
    }

    @Test
    func coordinatorUpdatesCustomSubclassWithExplicitLifecycleForwarding() {
        let hostViewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let webView = CustomViewportTestWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let coordinator = ViewportCoordinator(webView: webView)
        webView.viewportCoordinator = coordinator

        attach(webView, to: hostViewController.view)
        hostViewController.view.layoutIfNeeded()

        #expect(coordinator.resolvedHostViewControllerForTesting === hostViewController)
        #expect(coordinator.observationSuperviewForTesting === hostViewController.view)
        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        coordinator.invalidate()
    }

    @Test
    @available(iOS 26.0, *)
    func coordinatorReappliesViewportWhenNavigationStateChangesWithoutGeometryChange() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        attach(webView, to: hostViewController.view)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setToolbarHidden(false, animated: false)
        let window = makeWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let initialCount = coordinator.appliedViewportUpdateCountForTesting
        #expect(initialCount > 0)

        coordinator.handleObservedWebViewStateChangeForTesting()

        #expect(coordinator.appliedViewportUpdateCountForTesting == initialCount + 1)
        _ = try #require(coordinator.resolvedMetricsForTesting)
    }

    @Test
    func coordinatorPreservesKeyboardFrameAcrossHierarchyChanges() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let keyboardFrame = CGRect(x: 0, y: 300, width: 320, height: 216)
        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboardFrame)]
        )

        coordinator.update()

        #expect(coordinator.keyboardFrameInScreenForTesting == keyboardFrame)
        coordinator.invalidate()
    }

    @Test
    func resolvedMetricsDeriveContentScrollInsetFallbackFromLegacySafeAreaDelta() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 12, left: 4, bottom: 8, right: 6),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 4, bottom: 34, right: 6)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(
            resolvedMetrics.contentScrollInsetFallback == UIEdgeInsets(top: 44, left: 0, bottom: 54, right: 0)
        )
    }

    @Test
    func resolvedMetricsKeepSafeAreaInsetWhenAdjustmentBehaviorIsNever() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 12, left: 4, bottom: 8, right: 6),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 4, bottom: 34, right: 6)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .never,
            screenScale: 3
        )

        #expect(
            resolvedMetrics.contentScrollInsetFallback == UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0)
        )
    }

    @Test
    func resolvedMetricsExcludeKeyboardFromLegacyFallbackInset() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                keyboardOverlapHeight: 331,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(resolvedMetrics.obscuredInsets.bottom == 331)
        #expect(resolvedMetrics.contentScrollInsetFallback.bottom == 0)
        #expect(
            resolvedMetrics.legacyLayoutViewportSize(in: CGRect(x: 0, y: 0, width: 390, height: 844))
                == CGSize(width: 390, height: 454)
        )
    }

    @Test
    func viewportMetricsClampAdditionalObscuredInsetsToNonNegativeValues() {
        let metrics = ViewportMetrics(
            safeArea: .init(
                viewport: .zero,
                legacyFallbackBaseline: .zero
            ),
            obscuredInsets: UIEdgeInsets(top: 10, left: 0, bottom: 20, right: 0),
            keyboardOverlapHeight: 5,
            inputAccessoryOverlapHeight: 8,
            additionalObscuredContentInsets: UIEdgeInsets(top: -4, left: -3, bottom: 7, right: 2)
        )

        #expect(metrics.finalObscuredInsets == UIEdgeInsets(top: 10, left: 0, bottom: 27, right: 2))
        #expect(metrics.scrollFallbackObscuredInsets == UIEdgeInsets(top: 10, left: 0, bottom: 27, right: 2))
    }

    @Test
    func appliedViewportStateTracksFallbackInsetChanges() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let first = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInset: .zero,
            legacyLayoutViewportSize: CGSize(width: 390, height: 653)
        )
        let second = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInset: UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0),
            legacyLayoutViewportSize: CGSize(width: 390, height: 653)
        )

        #expect(first != second)
    }

    @Test
    func appliedViewportStateTracksLegacyLayoutViewportSizeChanges() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let first = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInset: resolvedMetrics.contentScrollInsetFallback,
            legacyLayoutViewportSize: CGSize(width: 390, height: 653)
        )
        let second = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInset: resolvedMetrics.contentScrollInsetFallback,
            legacyLayoutViewportSize: CGSize(width: 390, height: 640)
        )

        #expect(first != second)
    }

    @Test
    func appliedViewportStateIgnoresLegacyFallbackWhenNoFallbackIsApplied() {
        let firstResolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )
        let secondResolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 83, left: 0, bottom: 52, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let first = AppliedViewportState(
            resolvedMetrics: firstResolvedMetrics,
            contentScrollInset: nil,
            legacyLayoutViewportSize: nil
        )
        let second = AppliedViewportState(
            resolvedMetrics: secondResolvedMetrics,
            contentScrollInset: nil,
            legacyLayoutViewportSize: nil
        )

        #expect(first == second)
    }

    @Test
    func resolvedMetricsUseSeparateLegacyFallbackSafeAreaBaseline() {
        let metrics = ViewportMetrics(
            safeArea: .init(
                viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                legacyFallbackBaseline: UIEdgeInsets(top: 83, left: 0, bottom: 52, right: 0)
            ),
            obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let resolvedMetrics = ResolvedViewportMetrics(
            state: metrics,
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(metrics.safeArea.viewport == UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0))
        #expect(metrics.safeArea.legacyFallbackBaseline == UIEdgeInsets(top: 83, left: 0, bottom: 52, right: 0))
        #expect(resolvedMetrics.contentScrollInsetFallback == UIEdgeInsets(top: 20, left: 0, bottom: 36, right: 0))
    }

    @Test
    @available(iOS 26.0, *)
    func coordinatorKeepsAppliedObscuredInsetsUntilInvalidateWhenWebViewDetaches() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let constraints = attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        coordinator.additionalObscuredContentInsets.top = 12
        #expect(webView.obscuredContentInsets.top > 0)

        NSLayoutConstraint.deactivate(constraints)
        let orphanContainer = UIView()
        attach(webView, to: orphanContainer)
        coordinator.update()

        #expect(webView.obscuredContentInsets.top > 0)
        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(coordinator.observationSuperviewForTesting == nil)
        coordinator.invalidate()
        #expect(webView.obscuredContentInsets == .zero)
    }

    @Test
    func coordinatorSkipsAlreadyRegisteredContentScrollView() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let initialContentScrollViewRegistrationCount =
            coordinator.contentScrollViewRegistrationCountForTesting

        coordinator.update()

        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        #expect(hostViewController.contentScrollView(for: .bottom) === webView.scrollView)
        #expect(
            coordinator.contentScrollViewRegistrationCountForTesting
                == initialContentScrollViewRegistrationCount
        )
        coordinator.invalidate()
    }

    @Test
    func coordinatorRestoresContentScrollViewWhenOneEdgeDrifts() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        let replacementScrollView = UIScrollView()
        hostViewController.setContentScrollView(replacementScrollView, for: .top)
        let registrationCountBeforeRecovery =
            coordinator.contentScrollViewRegistrationCountForTesting

        #expect(hostViewController.contentScrollView(for: .top) === replacementScrollView)
        #expect(hostViewController.contentScrollView(for: .bottom) === webView.scrollView)

        coordinator.update()

        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        #expect(hostViewController.contentScrollView(for: .bottom) === webView.scrollView)
        #expect(
            coordinator.contentScrollViewRegistrationCountForTesting
                == registrationCountBeforeRecovery + 1
        )
        coordinator.invalidate()
    }

    @Test(arguments: [false, true])
    @available(iOS 26.0, *)
    func coordinatorDeinitClearsAppliedViewportStateWithoutExplicitInvalidate(usesManualInsets: Bool) {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.scrollView.contentInsetAdjustmentBehavior = usesManualInsets ? .never : .always
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        weak var releasedCoordinator: ViewportCoordinator?
        do {
            let coordinator = ViewportCoordinator(webView: webView)
        coordinator.additionalObscuredContentInsets.top = 12
            releasedCoordinator = coordinator
            #expect(webView.obscuredContentInsets.top > 0)
            if usesManualInsets {
                #expect(webView.scrollView.contentInset == webView.obscuredContentInsets)
            }
            #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        }

        #expect(releasedCoordinator == nil)
        #expect(webView.obscuredContentInsets == .zero)
        #expect(webView.scrollView.contentInset == .zero)
        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(hostViewController.contentScrollView(for: .bottom) == nil)
    }

    @Test
    func viewportSPIBridgeDoesNotRetainReceiversInCachedMethods() {
        weak var observed: TestInputBoundsSPIObject?
        let firstBounds = CGRect(x: 1, y: 2, width: 3, height: 4)
        autoreleasepool {
            let object = TestInputBoundsSPIObject()
            observed = object
            object.boundsInWindow = firstBounds
            #expect(ViewportSPIBridge.inputViewBoundsInWindow(of: object) == firstBounds)
        }
        #expect(observed == nil)

        let second = TestInputBoundsSPIObject()
        second.boundsInWindow = CGRect(x: 5, y: 6, width: 7, height: 8)
        #expect(ViewportSPIBridge.inputViewBoundsInWindow(of: second) == second.boundsInWindow)
    }

    @Test
    func viewportSPIBridgeFallbackNoOpsWhenSelectorsAreUnavailable() {
        let plainObject = NSObject()
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(
            ViewportSPIBridge.applyLegacyViewportFallback(
                resolvedMetrics,
                to: plainObject,
                webView: plainObject
            ) == false
        )
        #expect(
            ViewportSPIBridge.resetLegacyViewportFallback(
                on: plainObject,
                webView: plainObject
            ) == false
        )

        #expect(ViewportSPIBridge.inputViewBoundsInWindow(of: plainObject) == nil)
    }

    @Test
    func viewportSPIBridgeLegacyViewportFallbackAppliesSafeAreaMetadataInOrder() {
        let object = TestViewportSPIObject()
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(
            ViewportSPIBridge.applyLegacyViewportFallback(
                resolvedMetrics,
                to: object,
                webView: object
            )
        )
        #expect(object.obscuredInsetCalls == [resolvedMetrics.obscuredInsets])
        #expect(
            object.unobscuredSafeAreaInsetsCalls == [resolvedMetrics.unobscuredSafeAreaInsets]
        )
        #expect(
            object.layoutOverrideCalls == [
                .init(
                    minimumLayoutSize: CGSize(width: 390, height: 653),
                    minimumUnobscuredSizeOverride: CGSize(width: 390, height: 653),
                    maximumUnobscuredSizeOverride: CGSize(width: 390, height: 653)
                )
            ]
        )
        #expect(object.frameOrBoundsMayHaveChangedCallCount == 1)
        #expect(
            object.invocationOrder == [
                ViewportSPISelectorNames.setObscuredInsets,
                ViewportSPISelectorNames.setUnobscuredSafeAreaInsets,
                ViewportSPISelectorNames.scrollViewSystemContentInset,
                ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride,
                ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
            ]
        )
    }

    @Test
    func viewportSPIBridgeResetLegacyViewportFallbackClearsViewportMetadataInOrder() {
        let object = TestViewportSPIObject()

        #expect(
            ViewportSPIBridge.resetLegacyViewportFallback(
                on: object,
                webView: object
            )
        )
        #expect(object.obscuredInsetCalls.isEmpty)
        #expect(object.unobscuredSafeAreaInsetsCalls.isEmpty)
        #expect(object.clearOverrideLayoutParametersCallCount == 1)
        #expect(object.frameOrBoundsMayHaveChangedCallCount == 1)
        #expect(
            object.invocationOrder == [
                ViewportSPISelectorNames.resetObscuredInsets,
                ViewportSPISelectorNames.resetUnobscuredSafeAreaInsets,
                ViewportSPISelectorNames.clearOverrideLayoutParameters,
                ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
            ]
        )
    }

    @Test
    func viewportSPIBridgeResetLegacyViewportFallbackUsesNeutralOverrideWhenClearSelectorIsUnavailable() {
        let object = TestViewportSPIObjectWithoutClearOverride()

        #expect(
            ViewportSPIBridge.resetLegacyViewportFallback(
                on: object,
                webView: object
            )
        )
        #expect(object.obscuredInsetCalls.isEmpty)
        #expect(object.unobscuredSafeAreaInsetsCalls.isEmpty)
        #expect(
            object.layoutOverrideCalls == [
                .init(
                    minimumLayoutSize: CGSize(width: 390, height: 751),
                    minimumUnobscuredSizeOverride: CGSize(width: 390, height: 751),
                    maximumUnobscuredSizeOverride: CGSize(width: 390, height: 751)
                )
            ]
        )
        #expect(object.frameOrBoundsMayHaveChangedCallCount == 1)
        #expect(
            object.invocationOrder == [
                ViewportSPISelectorNames.resetObscuredInsets,
                ViewportSPISelectorNames.resetUnobscuredSafeAreaInsets,
                ViewportSPISelectorNames.scrollViewSystemContentInset,
                ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride,
                ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
            ]
        )
    }

    @Test
    func viewportSPIBridgeFallbackUsesInternalSelectorsAndMaximumOnlyLayoutOverride() {
        let object = TestViewportSPIObjectWithInternalSelectorsAndMaximumOnlyOverride()
        object.reportedSystemContentInset = UIEdgeInsets(top: 120, left: 0, bottom: 20, right: 0)
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                obscuredInsets: UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0),
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(
            ViewportSPIBridge.applyLegacyViewportFallback(
                resolvedMetrics,
                to: object,
                webView: object
            )
        )
        #expect(object.obscuredInsetsInternalCalls == [resolvedMetrics.obscuredInsets])
        #expect(object.unobscuredSafeAreaInsetsCalls == [resolvedMetrics.unobscuredSafeAreaInsets])
        #expect(
            object.layoutOverrideCalls == [
                .init(
                    minimumLayoutSize: CGSize(width: 390, height: 636),
                    minimumUnobscuredSizeOverride: CGSize(width: 390, height: 636),
                    maximumUnobscuredSizeOverride: CGSize(width: 390, height: 636)
                )
            ]
        )
        #expect(object.frameOrBoundsMayHaveChangedCallCount == 1)
        #expect(
            object.invocationOrder == [
                ViewportSPISelectorNames.setObscuredInsetsInternal,
                ViewportSPISelectorNames.setUnobscuredSafeAreaInsets,
                ViewportSPISelectorNames.systemContentInset,
                ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride,
                ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
            ]
        )
    }
}

@MainActor
private final class TestInputBoundsSPIObject: NSObject {
    var boundsInWindow: CGRect = .zero

    @objc(_inputViewBoundsInWindow)
    func inputViewBoundsInWindow() -> CGRect { boundsInWindow }
}

@MainActor
private func makeWindow(rootViewController: UIViewController) -> UIWindow {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = rootViewController
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
}

@MainActor
private func setFrame(of view: UIView, in window: UIWindow, to frameInWindow: CGRect) {
    guard let superview = view.superview else {
        return
    }
    view.frame = superview.convert(frameInWindow, from: window)
}

private struct LegacyLayoutOverrideCall: Equatable {
    let minimumLayoutSize: CGSize
    let minimumUnobscuredSizeOverride: CGSize
    let maximumUnobscuredSizeOverride: CGSize
}

private final class TestViewportSPIObject: UIView {
    private(set) var obscuredInsetCalls: [UIEdgeInsets] = []
    private(set) var unobscuredSafeAreaInsetsCalls: [UIEdgeInsets] = []
    private(set) var layoutOverrideCalls: [LegacyLayoutOverrideCall] = []
    private(set) var clearOverrideLayoutParametersCallCount = 0
    private(set) var frameOrBoundsMayHaveChangedCallCount = 0
    private(set) var invocationOrder: [String] = []
    var reportedScrollViewSystemContentInset = UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0)
    var reportedSystemContentInset = UIEdgeInsets(top: 103, left: 0, bottom: 88, right: 0)

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc(_resetObscuredInsets)
    func resetObscuredInsets() {
        invocationOrder.append(ViewportSPISelectorNames.resetObscuredInsets)
    }

    @objc(_resetUnobscuredSafeAreaInsets)
    func resetUnobscuredSafeAreaInsets() {
        invocationOrder.append(ViewportSPISelectorNames.resetUnobscuredSafeAreaInsets)
    }

    @objc(_setObscuredInsets:)
    func setObscuredInsets(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setObscuredInsets)
        obscuredInsetCalls.append(insets)
    }

    @objc(_setUnobscuredSafeAreaInsets:)
    func setUnobscuredSafeAreaInsets(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setUnobscuredSafeAreaInsets)
        unobscuredSafeAreaInsetsCalls.append(insets)
    }

    @objc(_scrollViewSystemContentInset)
    func scrollViewSystemContentInset() -> UIEdgeInsets {
        invocationOrder.append(ViewportSPISelectorNames.scrollViewSystemContentInset)
        return reportedScrollViewSystemContentInset
    }

    @objc(_systemContentInset)
    func systemContentInset() -> UIEdgeInsets {
        invocationOrder.append(ViewportSPISelectorNames.systemContentInset)
        return reportedSystemContentInset
    }

    @objc(_overrideLayoutParametersWithMinimumLayoutSize:minimumUnobscuredSizeOverride:maximumUnobscuredSizeOverride:)
    func overrideLayoutParameters(
        minimumLayoutSize: CGSize,
        minimumUnobscuredSizeOverride: CGSize,
        maximumUnobscuredSizeOverride: CGSize
    ) {
        invocationOrder.append(
            ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride
        )
        layoutOverrideCalls.append(
            LegacyLayoutOverrideCall(
                minimumLayoutSize: minimumLayoutSize,
                minimumUnobscuredSizeOverride: minimumUnobscuredSizeOverride,
                maximumUnobscuredSizeOverride: maximumUnobscuredSizeOverride
            )
        )
    }

    @objc(_overrideLayoutParametersWithMinimumLayoutSize:maximumUnobscuredSizeOverride:)
    func overrideLayoutParameters(
        minimumLayoutSize: CGSize,
        maximumUnobscuredSizeOverride: CGSize
    ) {
        invocationOrder.append(
            ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride
        )
        layoutOverrideCalls.append(
            LegacyLayoutOverrideCall(
                minimumLayoutSize: minimumLayoutSize,
                minimumUnobscuredSizeOverride: minimumLayoutSize,
                maximumUnobscuredSizeOverride: maximumUnobscuredSizeOverride
            )
        )
    }

    @objc(_clearOverrideLayoutParameters)
    func clearOverrideLayoutParameters() {
        invocationOrder.append(ViewportSPISelectorNames.clearOverrideLayoutParameters)
        clearOverrideLayoutParametersCallCount += 1
    }

    @objc(_frameOrBoundsMayHaveChanged)
    func frameOrBoundsMayHaveChanged() {
        invocationOrder.append(ViewportSPISelectorNames.frameOrBoundsMayHaveChanged)
        frameOrBoundsMayHaveChangedCallCount += 1
    }
}

private final class TestViewportSPIObjectWithoutClearOverride: UIView {
    private(set) var obscuredInsetCalls: [UIEdgeInsets] = []
    private(set) var unobscuredSafeAreaInsetsCalls: [UIEdgeInsets] = []
    private(set) var layoutOverrideCalls: [LegacyLayoutOverrideCall] = []
    private(set) var frameOrBoundsMayHaveChangedCallCount = 0
    private(set) var invocationOrder: [String] = []
    var reportedScrollViewSystemContentInset = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc(_resetObscuredInsets)
    func resetObscuredInsets() {
        invocationOrder.append(ViewportSPISelectorNames.resetObscuredInsets)
    }

    @objc(_resetUnobscuredSafeAreaInsets)
    func resetUnobscuredSafeAreaInsets() {
        invocationOrder.append(ViewportSPISelectorNames.resetUnobscuredSafeAreaInsets)
    }

    @objc(_setObscuredInsets:)
    func setObscuredInsets(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setObscuredInsets)
        obscuredInsetCalls.append(insets)
    }

    @objc(_setUnobscuredSafeAreaInsets:)
    func setUnobscuredSafeAreaInsets(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setUnobscuredSafeAreaInsets)
        unobscuredSafeAreaInsetsCalls.append(insets)
    }

    @objc(_scrollViewSystemContentInset)
    func scrollViewSystemContentInset() -> UIEdgeInsets {
        invocationOrder.append(ViewportSPISelectorNames.scrollViewSystemContentInset)
        return reportedScrollViewSystemContentInset
    }

    @objc(_overrideLayoutParametersWithMinimumLayoutSize:minimumUnobscuredSizeOverride:maximumUnobscuredSizeOverride:)
    func overrideLayoutParameters(
        minimumLayoutSize: CGSize,
        minimumUnobscuredSizeOverride: CGSize,
        maximumUnobscuredSizeOverride: CGSize
    ) {
        invocationOrder.append(
            ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMinimumUnobscuredSizeOverrideMaximumUnobscuredSizeOverride
        )
        layoutOverrideCalls.append(
            LegacyLayoutOverrideCall(
                minimumLayoutSize: minimumLayoutSize,
                minimumUnobscuredSizeOverride: minimumUnobscuredSizeOverride,
                maximumUnobscuredSizeOverride: maximumUnobscuredSizeOverride
            )
        )
    }

    @objc(_frameOrBoundsMayHaveChanged)
    func frameOrBoundsMayHaveChanged() {
        invocationOrder.append(ViewportSPISelectorNames.frameOrBoundsMayHaveChanged)
        frameOrBoundsMayHaveChangedCallCount += 1
    }
}

private final class TestViewportSPIObjectWithInternalSelectorsAndMaximumOnlyOverride: UIView {
    private(set) var obscuredInsetsInternalCalls: [UIEdgeInsets] = []
    private(set) var unobscuredSafeAreaInsetsCalls: [UIEdgeInsets] = []
    private(set) var layoutOverrideCalls: [LegacyLayoutOverrideCall] = []
    private(set) var frameOrBoundsMayHaveChangedCallCount = 0
    private(set) var invocationOrder: [String] = []
    var reportedSystemContentInset = UIEdgeInsets(top: 120, left: 0, bottom: 20, right: 0)

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc(_setObscuredInsetsInternal:)
    func setObscuredInsetsInternal(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setObscuredInsetsInternal)
        obscuredInsetsInternalCalls.append(insets)
    }

    @objc(_setUnobscuredSafeAreaInsets:)
    func setUnobscuredSafeAreaInsets(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setUnobscuredSafeAreaInsets)
        unobscuredSafeAreaInsetsCalls.append(insets)
    }

    @objc(_systemContentInset)
    func systemContentInset() -> UIEdgeInsets {
        invocationOrder.append(ViewportSPISelectorNames.systemContentInset)
        return reportedSystemContentInset
    }

    @objc(_overrideLayoutParametersWithMinimumLayoutSize:maximumUnobscuredSizeOverride:)
    func overrideLayoutParameters(
        minimumLayoutSize: CGSize,
        maximumUnobscuredSizeOverride: CGSize
    ) {
        invocationOrder.append(
            ViewportSPISelectorNames.overrideLayoutParametersWithMinimumLayoutSizeMaximumUnobscuredSizeOverride
        )
        layoutOverrideCalls.append(
            LegacyLayoutOverrideCall(
                minimumLayoutSize: minimumLayoutSize,
                minimumUnobscuredSizeOverride: minimumLayoutSize,
                maximumUnobscuredSizeOverride: maximumUnobscuredSizeOverride
            )
        )
    }

    @objc(_frameOrBoundsMayHaveChanged)
    func frameOrBoundsMayHaveChanged() {
        invocationOrder.append(ViewportSPISelectorNames.frameOrBoundsMayHaveChanged)
        frameOrBoundsMayHaveChangedCallCount += 1
    }
}

@MainActor
private final class ContainerViewBox {
    var view: UIView?
    let attachedToWindow = XCTestExpectation(description: "SwiftUI container attached to window")
}

@MainActor
private final class HostingContainerView: UIView {
    weak var box: ContainerViewBox?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            box?.view = self
            box?.attachedToWindow.fulfill()
        }
    }
}

@MainActor
private final class CustomViewportTestWebView: WKWebView {
    weak var viewportCoordinator: ViewportCoordinator?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        viewportCoordinator?.update()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportCoordinator?.update()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        viewportCoordinator?.update()
    }
}

private final class InputAccessoryReportingWebView: WKWebView {
    var reportedInputViewBoundsInWindow: CGRect = .null

    @objc(_inputViewBoundsInWindow)
    func inputViewBoundsInWindow() -> CGRect {
        reportedInputViewBoundsInWindow
    }
}

private struct HostingWebViewContainer: View {
    let webView: WKWebView
    let box: ContainerViewBox

    var body: some View {
        HostingWebViewRepresentable(webView: webView, box: box)
    }
}

private struct HostingWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    let box: ContainerViewBox

    func makeUIView(context: Context) -> UIView {
        let containerView = HostingContainerView()
        containerView.box = box
        attach(webView, to: containerView)
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

@MainActor
@discardableResult
private func attach(_ webView: WKWebView, to containerView: UIView) -> [NSLayoutConstraint] {
    webView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(webView)
    let constraints = [
        webView.topAnchor.constraint(equalTo: containerView.topAnchor),
        webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
    ]
    NSLayoutConstraint.activate(constraints)
    return constraints
}

@MainActor
private func projectedWindowSafeAreaInsets(in hostView: UIView) -> UIEdgeInsets {
    guard let window = hostView.window else {
        return .zero
    }

    let hostRectInWindow = hostView.convert(hostView.bounds, to: window)
    let safeRectInWindow = window.bounds.inset(by: window.safeAreaInsets)

    return UIEdgeInsets(
        top: max(0, safeRectInWindow.minY - hostRectInWindow.minY),
        left: max(0, safeRectInWindow.minX - hostRectInWindow.minX),
        bottom: max(0, hostRectInWindow.maxY - safeRectInWindow.maxY),
        right: max(0, hostRectInWindow.maxX - safeRectInWindow.maxX)
    )
}

@MainActor
private func bottomEdgeObscuredHeight(of chromeView: UIView?, in hostView: UIView) -> CGFloat {
    bottomEdgeObscuredHeight(of: [chromeView], in: hostView)
}

@MainActor
private func bottomEdgeObscuredHeight(
    of chromeViews: [UIView?],
    in hostView: UIView,
    extendingFrom trailingObscuredHeight: CGFloat = 0
) -> CGFloat {
    guard let window = hostView.window else {
        return max(0, trailingObscuredHeight)
    }

    let hostFrameInWindow = hostView.convert(hostView.bounds, to: window)
    let chromeFramesInWindow = chromeViews.compactMap { chromeView -> CGRect? in
        guard let chromeView, chromeView.window != nil else {
            return nil
        }
        guard chromeView.isHidden == false, effectiveAlpha(of: chromeView) > 0 else {
            return nil
        }
        return chromeView.convert(chromeView.bounds, to: window)
    }

    var obscuredMinY = hostFrameInWindow.maxY - max(0, trailingObscuredHeight)
    var didExtend = true

    while didExtend {
        didExtend = false

        for chromeFrameInWindow in chromeFramesInWindow {
            guard chromeFrameInWindow.minY < hostFrameInWindow.maxY else {
                continue
            }
            guard chromeFrameInWindow.maxY > hostFrameInWindow.minY else {
                continue
            }

            let overlapMinY = max(hostFrameInWindow.minY, chromeFrameInWindow.minY)
            let overlapMaxY = min(hostFrameInWindow.maxY, chromeFrameInWindow.maxY)
            guard overlapMaxY >= obscuredMinY else {
                continue
            }
            guard overlapMinY < obscuredMinY else {
                continue
            }

            obscuredMinY = overlapMinY
            didExtend = true
        }
    }

    return max(0, hostFrameInWindow.maxY - obscuredMinY)
}

@MainActor
private func effectiveAlpha(of view: UIView) -> CGFloat {
    var alpha = view.alpha
    var currentSuperview = view.superview

    while let superview = currentSuperview {
        if superview.isHidden {
            return 0
        }
        alpha *= superview.alpha
        currentSuperview = superview.superview
    }

    return alpha
}
#endif
