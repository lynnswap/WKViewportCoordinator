#if canImport(UIKit)
import Testing
import UIKit
import WebKit
@testable import WKViewportCoordinator

@MainActor
extension ViewportCoordinatorTests {
    @Test
    func viewportWebViewFindsHostViewControllerAutomatically() {
        let hostViewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeManagedViewportWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let webView = ViewportWebView(
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

        #expect(webView.viewportCoordinator.resolvedHostViewControllerForTesting === hostViewController)
        #expect(webView.viewportCoordinator.resolvedHostViewControllerForTesting === hostViewController)
        #expect(hostViewController.contentScrollView(for: .top) === webView.scrollView)
    }

    @Test
    func viewportWebViewPrefersExplicitHostViewControllerOverride() {
        let hostViewController = UIViewController()
        let overrideHostViewController = UIViewController()
        overrideHostViewController.loadViewIfNeeded()

        let navigationController = UINavigationController(rootViewController: hostViewController)
        let window = makeManagedViewportWindow(rootViewController: navigationController)
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let webView = ViewportWebView(
            frame: .zero,
            configuration: WKWebViewConfiguration()
        )
        webView.viewportCoordinator.hostViewController = overrideHostViewController
        hostViewController.view.addSubview(webView)
        hostViewController.view.layoutIfNeeded()

        #expect(webView.viewportCoordinator.resolvedHostViewControllerForTesting === overrideHostViewController)
        #expect(webView.viewportCoordinator.hostViewController === overrideHostViewController)
    }

    @Test
    func viewportWebViewKeepsConfigurationOnItsCoordinator() throws {
        let controller = UIViewController()
        let window = makeManagedViewportWindow(rootViewController: controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        let webView = ViewportWebView(frame: controller.view.bounds)
        controller.view.addSubview(webView)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let coordinator = webView.viewportCoordinator
        coordinator.includesNavigationBar = false
        coordinator.additionalObscuredContentInsets = UIEdgeInsets(top: -8, left: -4, bottom: 12, right: 6)
        coordinator.update()
        #expect(webView.viewportCoordinator === coordinator)
        #expect(coordinator.additionalObscuredContentInsets == UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 6))
        #expect(!coordinator.includesNavigationBar)
        #expect(try #require(coordinator.resolvedMetricsForTesting).obscuredInsets.bottom >= 12)
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
