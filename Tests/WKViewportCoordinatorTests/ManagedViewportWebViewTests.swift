#if canImport(UIKit)
import Testing
import UIKit
import WebKit
@testable import WKViewportCoordinator

@MainActor
struct ManagedViewportWebViewTests {
    @Test
    func managedViewportWebViewFindsHostViewControllerAutomatically() {
        let hostViewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeManagedViewportWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let webView = ManagedViewportWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration()
        )
        webView.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        hostViewController.view.layoutIfNeeded()

        #expect(webView.resolvedHostViewControllerForTesting === hostViewController)
        #expect(webView.activeViewportCoordinatorForTesting?.resolvedHostViewControllerForTesting === hostViewController)
        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
    }

    @Test
    func managedViewportWebViewPrefersExplicitHostViewControllerOverride() {
        let hostViewController = UIViewController()
        let overrideHostViewController = UIViewController()
        overrideHostViewController.loadViewIfNeeded()

        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeManagedViewportWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let webView = ManagedViewportWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration()
        )
        webView.viewportHostViewController = overrideHostViewController
        hostViewController.view.addSubview(webView)
        hostViewController.view.layoutIfNeeded()

        #expect(webView.resolvedHostViewControllerForTesting === overrideHostViewController)
        #expect(webView.activeViewportCoordinatorForTesting?.hostViewController === overrideHostViewController)
    }

    @Test
    func managedViewportWebViewForwardsViewportProxyUpdates() throws {
        let hostViewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeManagedViewportWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let webView = ManagedViewportWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration()
        )
        webView.translatesAutoresizingMaskIntoConstraints = false
        hostViewController.view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: hostViewController.view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: hostViewController.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: hostViewController.view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: hostViewController.view.bottomAnchor)
        ])

        hostViewController.view.layoutIfNeeded()

        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.viewportObscuredContentInsetEdgesAffectedBySafeArea = [.bottom]
        webView.viewportAdditionalObscuredContentInsets = UIEdgeInsets(top: -8, left: -4, bottom: 12, right: 6)
        webView.viewportBottomBarObscurationBehavior = .ignoreWhenKeyboardOrAccessoryOverlaps
        webView.viewportScrollEdgeEffects = ViewportScrollEdgeEffects(
            top: ViewportScrollEdgeEffect(isHidden: true, style: .hard),
            bottom: ViewportScrollEdgeEffect(isHidden: false, style: .automatic)
        )

        let coordinator = try #require(webView.activeViewportCoordinatorForTesting)
        let resolvedMetrics = try #require(coordinator.resolvedMetricsForTesting)

        #expect(coordinator.obscuredContentInsetEdgesAffectedBySafeArea == [.bottom])
        #expect(
            coordinator.additionalObscuredContentInsets
                == UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 6)
        )
        #expect(webView.viewportAdditionalObscuredContentInsets == UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 6))
        #expect(coordinator.bottomBarObscurationBehavior == .ignoreWhenKeyboardOrAccessoryOverlaps)
        #expect(
            coordinator.scrollEdgeEffects
                == ViewportScrollEdgeEffects(
                    top: ViewportScrollEdgeEffect(isHidden: true, style: .hard),
                    bottom: ViewportScrollEdgeEffect(isHidden: false, style: .automatic)
                )
        )
        #expect(webView.scrollView.contentInsetAdjustmentBehavior == .never)
        #expect(resolvedMetrics.contentInsetAdjustmentBehavior == .never)
        #expect(resolvedMetrics.obscuredContentInsetEdgesAffectedBySafeArea == [.bottom])
        #expect(resolvedMetrics.obscuredInsets.left == 0)
        #expect(resolvedMetrics.obscuredInsets.right == 6)
        #expect(resolvedMetrics.obscuredInsets.bottom >= 12)
    }
}

@MainActor
private func makeManagedViewportWindow(rootViewController: UIViewController) -> UIWindow {
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = rootViewController
    window.makeKeyAndVisible()
    window.layoutIfNeeded()
    return window
}

#endif
