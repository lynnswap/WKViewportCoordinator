#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import WebKit
@testable import WKViewportCoordinator

@MainActor
struct ViewportCoordinatorTests {
    @Test
    func resolvedMetricsRoundInsetsToPixelBoundaries() {
        let first = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 58.97, left: 0, bottom: 34.02, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 58.97, left: 0, bottom: 34.02, right: 0)
                ),
                topObscuredHeight: 102.98,
                bottomObscuredHeight: 87.96,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
                topObscuredHeight: 103.01,
                bottomObscuredHeight: 87.99,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(first == second)
        #expect(first.obscuredInsets.top == 103)
        #expect(first.obscuredInsets.bottom == 88)
    }

    @Test
    func viewportMetricsProviderUsesProjectedWindowSafeAreaWhenNoChromeOverlaps() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)
        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = window.bounds
        hostViewController.view.layoutIfNeeded()
        window.layoutIfNeeded()

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: hostView))
        #expect(metrics.safeArea.legacyFallbackBaseline == hostView.safeAreaInsets)
        #expect(metrics.topObscuredHeight == metrics.safeArea.viewport.top)
        #expect(metrics.bottomObscuredHeight == metrics.safeArea.viewport.bottom)
    }

    @Test
    func viewportMetricsProviderIncludesVisibleNavigationBarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

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

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: try #require(webView.superview)))
        #expect(
            metrics.topObscuredHeight
                == max(
                    metrics.safeArea.viewport.top,
                    topEdgeObscuredHeight(
                        of: navigationController.navigationBar,
                        in: try #require(webView.superview),
                        extendingFrom: metrics.safeArea.viewport.top
                    )
                )
        )
    }

    @Test
    func viewportMetricsProviderIgnoresNavigationBarThatDoesNotReachTopEdge() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

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

        var navigationBarFrame = navigationController.navigationBar.frame
        navigationBarFrame.origin.y = navigationController.view.bounds.midY
        navigationController.navigationBar.frame = navigationBarFrame

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)
        let topEdgeHeight = topEdgeObscuredHeight(
            of: navigationController.navigationBar,
            in: hostView,
            extendingFrom: metrics.safeArea.viewport.top
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: hostView))
        #expect(topEdgeHeight == 0)
        #expect(metrics.topObscuredHeight == metrics.safeArea.viewport.top)
    }

    @Test
    func viewportMetricsProviderIncludesVisibleTabBarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

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

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: try #require(webView.superview)))
        #expect(
            metrics.bottomObscuredHeight
                == max(
                    metrics.safeArea.viewport.bottom,
                    bottomEdgeObscuredHeight(of: tabBarController.tabBar, in: try #require(webView.superview))
                )
        )
    }

    @Test
    func viewportMetricsProviderIncludesVisibleToolbarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

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

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
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
            metrics.bottomObscuredHeight == bottomObscuredHeight
        )
    }

    @Test
    func viewportMetricsProviderIncludesStackedBottomChromeOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

        let navigationController = UINavigationController(rootViewController: hostViewController)
        navigationController.setToolbarHidden(false, animated: false)
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([navigationController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        hostViewController.view.frame = tabBarController.view.bounds
        hostViewController.view.layoutIfNeeded()
        navigationController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)
        let stackedBottomObscuredHeight = bottomEdgeObscuredHeight(
            of: [tabBarController.tabBar, navigationController.toolbar],
            in: hostView,
            extendingFrom: metrics.safeArea.viewport.bottom
        )

        #expect(metrics.bottomObscuredHeight == stackedBottomObscuredHeight)
        #expect(metrics.bottomObscuredHeight > bottomEdgeObscuredHeight(of: tabBarController.tabBar, in: hostView))
        #expect(metrics.bottomObscuredHeight > bottomEdgeObscuredHeight(of: navigationController.toolbar, in: hostView))
    }

    @Test
    func viewportMetricsProviderIgnoresHiddenTabBarOverlap() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([hostViewController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        tabBarController.tabBar.isHidden = true
        tabBarController.tabBar.alpha = 0
        hostViewController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: try #require(webView.superview)))
        #expect(metrics.bottomObscuredHeight == metrics.safeArea.viewport.bottom)
    }

    @Test
    func viewportMetricsProviderIgnoresTabBarThatDoesNotReachBottomEdge() throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

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

        var tabBarFrame = tabBarController.tabBar.frame
        tabBarFrame.origin.y = hostViewController.view.bounds.minY
        tabBarController.tabBar.frame = tabBarFrame

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.bottomObscuredHeight == metrics.safeArea.viewport.bottom)
    }

    @Test
    func viewportMetricsProviderSeparatesViewportAndLegacyFallbackSafeAreas() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        hostViewController.view.addSubview(webView)

        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([hostViewController], animated: false)
        let window = makeWindow(rootViewController: tabBarController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let provider = ViewportMetricsProvider()
        let baseline = provider.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        hostViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 16, left: 0, bottom: 48, right: 0)
        hostViewController.view.setNeedsLayout()
        hostViewController.view.layoutIfNeeded()
        tabBarController.view.layoutIfNeeded()

        let updated = provider.makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(updated.safeArea.viewport == baseline.safeArea.viewport)
        #expect(updated.safeArea.legacyFallbackBaseline == hostViewController.view.safeAreaInsets)
        #expect(updated.safeArea.legacyFallbackBaseline != baseline.safeArea.legacyFallbackBaseline)
        #expect(updated.topObscuredHeight == baseline.topObscuredHeight)
        #expect(updated.bottomObscuredHeight == baseline.bottomObscuredHeight)
    }

    @Test
    func viewportMetricsProviderProjectsWindowSafeAreaIntoContainerSubview() throws {
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

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )
        let hostView = try #require(webView.superview)

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: hostView))
        #expect(metrics.safeArea.legacyFallbackBaseline == hostView.safeAreaInsets)
        #expect(metrics.topObscuredHeight == 0)
        #expect(metrics.bottomObscuredHeight == 0)
    }

    @Test
    func viewportMetricsProviderUsesWebViewSuperviewWhenSwiftUIInsetsViewport() throws {
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

        let metrics = ViewportMetricsProvider().makeViewportMetrics(
            in: hostViewController,
            webView: webView,
            keyboardOverlapHeight: 0,
            inputAccessoryOverlapHeight: 0
        )

        #expect(metrics.safeArea.viewport == projectedWindowSafeAreaInsets(in: viewportContainer))
        #expect(metrics.safeArea.legacyFallbackBaseline == viewportContainer.safeAreaInsets)
        #expect(
            metrics.topObscuredHeight
                == max(
                    metrics.safeArea.viewport.top,
                    topEdgeObscuredHeight(
                        of: navigationController.navigationBar,
                        in: viewportContainer,
                        extendingFrom: metrics.safeArea.viewport.top
                    )
                )
        )
        #expect(metrics.topObscuredHeight == 0)
    }

    @Test
    func coordinatorInstallsObservationViewWhenHostViewLoadsAfterInitialization() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let coordinator = ViewportCoordinator(
            hostViewController: hostViewController,
            webView: webView
        )
        #expect(coordinator.hasObservationViewForTesting == false)

        webView.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(webView)
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

        coordinator.handleWebViewHierarchyDidChange()

        #expect(coordinator.hasObservationViewForTesting == true)
        #expect(coordinator.observationSuperviewForTesting === hostViewController.view)
        #expect(coordinator.resolvedMetricsForTesting != nil)
    }

    @Test
    func coordinatorResolvesHostViewControllerFromResponderChain() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(webView)
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
        hostViewController.view.addSubview(webView)
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
        try await Task.sleep(for: .milliseconds(10))

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
        let coordinator = ViewportCoordinator(hostViewController: hostViewController, webView: webView)
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

        let coordinator = ViewportCoordinator(hostViewController: hostViewController, webView: webView)
        let resolvedMetrics = try #require(coordinator.resolvedMetricsForTesting)
        #expect(resolvedMetrics.obscuredInsets.bottom == 0)
        coordinator.invalidate()
    }

    @Test
    func coordinatorReusesObservationViewWhileSuperviewIsStable() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(webView)
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

        coordinator.updateViewport()

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

        let coordinator = ViewportCoordinator(hostViewController: hostViewController, webView: webView)
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
        coordinator.handleWebViewHierarchyDidChange()

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
        coordinator.handleWebViewHierarchyDidChange()

        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(hostViewController.contentScrollView(for: .bottom) == nil)
        #expect(coordinator.observationSuperviewForTesting == nil)
        #expect(coordinator.resolvedMetricsForTesting == nil)
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
        coordinator.handleWebViewHierarchyDidChange()

        NSLayoutConstraint.deactivate(orphanConstraints)
        webView.removeFromSuperview()
        attach(webView, to: hostViewController.view)
        hostViewController.view.layoutIfNeeded()
        coordinator.handleWebViewHierarchyDidChange()

        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        #expect(hostViewController.contentScrollView(for: .bottom) === webView.scrollView)
        #expect(coordinator.observationSuperviewForTesting === hostViewController.view)
        coordinator.invalidate()
    }

    @Test
    func coordinatorInvalidateClearsLegacySafeAreaOverrides() {
        let hostViewController = UIViewController()
        let webView = LegacySafeAreaReportingWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)

        #expect(webView.unobscuredSafeAreaInsetsCalls.isEmpty == false)
        #expect(
            webView.obscuredInsetEdgesAffectedBySafeAreaCalls.last
                == UIRectEdge.top.union(.bottom).rawValue
        )

        coordinator.invalidate()

        #expect(webView.unobscuredSafeAreaInsetsCalls.last == .zero)
        #expect(webView.obscuredInsetEdgesAffectedBySafeAreaCalls.last == 0)
        #expect(webView.clearOverrideLayoutParametersCallCount == 1)
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
        hostViewController.view.addSubview(webView)
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

        coordinator.handleWebViewHierarchyDidChange()

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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
                topObscuredHeight: 59,
                bottomObscuredHeight: 34,
                keyboardOverlapHeight: 331,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
    func appliedViewportStateTracksFallbackInsetChanges() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let first = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInsetFallback: .zero,
            legacyLayoutViewportSize: CGSize(width: 390, height: 653)
        )
        let second = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInsetFallback: UIEdgeInsets(top: 1, left: 0, bottom: 0, right: 0),
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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let first = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInsetFallback: resolvedMetrics.contentScrollInsetFallback,
            legacyLayoutViewportSize: CGSize(width: 390, height: 653)
        )
        let second = AppliedViewportState(
            resolvedMetrics: resolvedMetrics,
            contentScrollInsetFallback: resolvedMetrics.contentScrollInsetFallback,
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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        let first = AppliedViewportState(
            resolvedMetrics: firstResolvedMetrics,
            contentScrollInsetFallback: nil,
            legacyLayoutViewportSize: nil
        )
        let second = AppliedViewportState(
            resolvedMetrics: secondResolvedMetrics,
            contentScrollInsetFallback: nil,
            legacyLayoutViewportSize: nil
        )

        #expect(first == second)
    }

    @Test
    func customMetricsProviderControlsLegacyFallbackSafeArea() {
        let metrics = StaticViewportMetricsSource().makeViewportMetrics(
            in: UIViewController(),
            webView: WKWebView(frame: .zero),
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
    func resolvedMetricsSubtractSafeAreaOnlyForAffectedEdgesInFallback() {
        let resolvedMetrics = ResolvedViewportMetrics(
            state: ViewportMetrics(
                safeArea: .init(
                    viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                    legacyFallbackBaseline: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
                ),
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal,
                safeAreaAffectedEdges: [.bottom]
            ),
            contentInsetAdjustmentBehavior: .always,
            screenScale: 3
        )

        #expect(
            resolvedMetrics.contentScrollInsetFallback == UIEdgeInsets(top: 103, left: 0, bottom: 54, right: 0)
        )
    }

    @Test
    @available(iOS 26.0, *)
    func coordinatorKeepsAppliedObscuredInsetsUntilInvalidateWhenWebViewDetaches() async throws {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        let constraints = attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let coordinator = ViewportCoordinator(webView: webView)
        #expect(webView.obscuredContentInsets.top > 0)

        NSLayoutConstraint.deactivate(constraints)
        let orphanContainer = UIView()
        attach(webView, to: orphanContainer)
        coordinator.handleWebViewHierarchyDidChange()
        try await Task.sleep(for: .milliseconds(10))

        #expect(webView.obscuredContentInsets.top > 0)
        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(coordinator.observationSuperviewForTesting == nil)
        coordinator.invalidate()
        #expect(webView.obscuredContentInsets == .zero)
    }

    @Test
    @available(iOS 26.0, *)
    func coordinatorDeinitClearsAppliedViewportStateWithoutExplicitInvalidate() {
        let hostViewController = UIViewController()
        let webView = WKWebView(frame: .zero)
        attach(webView, to: hostViewController.view)

        let window = makeWindow(rootViewController: hostViewController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        weak var releasedCoordinator: ViewportCoordinator?
        do {
            let coordinator = ViewportCoordinator(webView: webView)
            releasedCoordinator = coordinator
            #expect(webView.obscuredContentInsets.top > 0)
            #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
        }

        #expect(releasedCoordinator == nil)
        #expect(webView.obscuredContentInsets == .zero)
        #expect(hostViewController.contentScrollView(for: .top) == nil)
        #expect(hostViewController.contentScrollView(for: .bottom) == nil)
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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
                topObscuredHeight: 103,
                bottomObscuredHeight: 88,
                keyboardOverlapHeight: 0,
                inputAccessoryOverlapHeight: 0,
                bottomChromeMode: .normal
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
        #expect(object.contentScrollInsetCalls == [resolvedMetrics.contentScrollInsetFallback])
        #expect(object.obscuredInsetCalls == [resolvedMetrics.obscuredInsets])
        #expect(
            object.unobscuredSafeAreaInsetsCalls == [resolvedMetrics.unobscuredSafeAreaInsets]
        )
        #expect(object.obscuredSafeAreaEdgeCalls == [resolvedMetrics.safeAreaAffectedEdges.rawValue])
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
                ViewportSPISelectorNames.setContentScrollInset,
                ViewportSPISelectorNames.setObscuredInsets,
                ViewportSPISelectorNames.setUnobscuredSafeAreaInsets,
                ViewportSPISelectorNames.setObscuredInsetEdgesAffectedBySafeArea,
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
        #expect(object.contentScrollInsetCalls == [.zero])
        #expect(object.obscuredInsetCalls == [.zero])
        #expect(object.unobscuredSafeAreaInsetsCalls == [.zero])
        #expect(object.obscuredSafeAreaEdgeCalls == [0])
        #expect(object.clearOverrideLayoutParametersCallCount == 1)
        #expect(object.frameOrBoundsMayHaveChangedCallCount == 1)
        #expect(
            object.invocationOrder == [
                ViewportSPISelectorNames.setContentScrollInset,
                ViewportSPISelectorNames.setObscuredInsets,
                ViewportSPISelectorNames.setUnobscuredSafeAreaInsets,
                ViewportSPISelectorNames.setObscuredInsetEdgesAffectedBySafeArea,
                ViewportSPISelectorNames.clearOverrideLayoutParameters,
                ViewportSPISelectorNames.frameOrBoundsMayHaveChanged
            ]
        )
    }
}

@MainActor
private func makeWindow(rootViewController: UIViewController) -> UIWindow {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = rootViewController
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
}

private struct LegacyLayoutOverrideCall: Equatable {
    let minimumLayoutSize: CGSize
    let minimumUnobscuredSizeOverride: CGSize
    let maximumUnobscuredSizeOverride: CGSize
}

private final class TestViewportSPIObject: UIView {
    private(set) var contentScrollInsetCalls: [UIEdgeInsets] = []
    private(set) var obscuredInsetCalls: [UIEdgeInsets] = []
    private(set) var unobscuredSafeAreaInsetsCalls: [UIEdgeInsets] = []
    private(set) var obscuredSafeAreaEdgeCalls: [UInt] = []
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

    @objc(_setContentScrollInset:)
    func setContentScrollInset(_ insets: UIEdgeInsets) {
        invocationOrder.append(ViewportSPISelectorNames.setContentScrollInset)
        contentScrollInsetCalls.append(insets)
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

    @objc(_setObscuredInsetEdgesAffectedBySafeArea:)
    func setObscuredInsetEdgesAffectedBySafeArea(_ edges: UInt) {
        invocationOrder.append(ViewportSPISelectorNames.setObscuredInsetEdgesAffectedBySafeArea)
        obscuredSafeAreaEdgeCalls.append(edges)
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

@MainActor
private final class ContainerViewBox {
    var view: UIView?
}

@MainActor
private final class CustomViewportTestWebView: WKWebView {
    weak var viewportCoordinator: ViewportCoordinator?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        viewportCoordinator?.handleWebViewHierarchyDidChange()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        viewportCoordinator?.handleWebViewHierarchyDidChange()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        viewportCoordinator?.handleWebViewSafeAreaInsetsDidChange()
    }
}

private final class LegacySafeAreaReportingWebView: WKWebView {
    private(set) var obscuredInsetCalls: [UIEdgeInsets] = []
    private(set) var unobscuredSafeAreaInsetsCalls: [UIEdgeInsets] = []
    private(set) var obscuredInsetEdgesAffectedBySafeAreaCalls: [UInt] = []
    private(set) var clearOverrideLayoutParametersCallCount = 0

    @objc(_setObscuredInsets:)
    func setObscuredInsets(_ insets: UIEdgeInsets) {
        obscuredInsetCalls.append(insets)
    }

    @objc(_setUnobscuredSafeAreaInsets:)
    func setUnobscuredSafeAreaInsets(_ insets: UIEdgeInsets) {
        unobscuredSafeAreaInsetsCalls.append(insets)
    }

    @objc(_setObscuredInsetEdgesAffectedBySafeArea:)
    func setObscuredInsetEdgesAffectedBySafeArea(_ edges: UInt) {
        obscuredInsetEdgesAffectedBySafeAreaCalls.append(edges)
    }

    @objc(_clearOverrideLayoutParameters)
    func clearOverrideLayoutParameters() {
        clearOverrideLayoutParametersCallCount += 1
    }
}

private final class InputAccessoryReportingWebView: WKWebView {
    var reportedInputViewBoundsInWindow: CGRect = .null

    @objc(_inputViewBoundsInWindow)
    func inputViewBoundsInWindow() -> CGRect {
        reportedInputViewBoundsInWindow
    }
}

private struct StaticViewportMetricsSource: ViewportMetricsSource {
    func makeViewportMetrics(
        in hostViewController: UIViewController,
        webView: WKWebView,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat
    ) -> ViewportMetrics {
        ViewportMetrics(
            safeArea: .init(
                viewport: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                legacyFallbackBaseline: UIEdgeInsets(top: 83, left: 0, bottom: 52, right: 0)
            ),
            topObscuredHeight: 103,
            bottomObscuredHeight: 88,
            keyboardOverlapHeight: keyboardOverlapHeight,
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight,
            bottomChromeMode: .normal
        )
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
        let containerView = UIView()
        box.view = containerView
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
private func topEdgeObscuredHeight(
    of chromeView: UIView?,
    in hostView: UIView,
    extendingFrom leadingObscuredHeight: CGFloat = 0
) -> CGFloat {
    guard let chromeView else {
        return 0
    }
    guard let window = hostView.window, chromeView.window != nil else {
        return 0
    }
    guard chromeView.isHidden == false, effectiveAlpha(of: chromeView) > 0 else {
        return 0
    }

    let hostFrameInWindow = hostView.convert(hostView.bounds, to: window)
    let chromeFrameInWindow = chromeView.convert(chromeView.bounds, to: window)
    let leadingObscuredMaxY = hostFrameInWindow.minY + max(0, leadingObscuredHeight)
    guard chromeFrameInWindow.minY <= leadingObscuredMaxY else {
        return 0
    }
    guard chromeFrameInWindow.maxY > hostFrameInWindow.minY else {
        return 0
    }

    return max(
        max(0, leadingObscuredHeight),
        max(0, min(hostFrameInWindow.maxY, chromeFrameInWindow.maxY) - hostFrameInWindow.minY)
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
