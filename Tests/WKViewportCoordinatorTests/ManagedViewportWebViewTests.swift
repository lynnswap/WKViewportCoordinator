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
    func managedViewportWebViewForwardsConfigurationAndMetricsProviderUpdates() throws {
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

        let metricsProvider = ManagedViewportStaticMetricsSource()
        webView.viewportConfiguration = ViewportConfiguration(contentInsetAdjustmentBehavior: .never)
        webView.viewportMetricsProvider = metricsProvider

        let coordinator = try #require(webView.activeViewportCoordinatorForTesting)
        let resolvedMetrics = try #require(coordinator.resolvedMetricsForTesting)

        #expect(coordinator.configuration.contentInsetAdjustmentBehavior == .never)
        #expect(coordinator.metricsProvider as? ManagedViewportStaticMetricsSource === metricsProvider)
        #expect(webView.scrollView.contentInsetAdjustmentBehavior == .never)
        #expect(resolvedMetrics.contentInsetAdjustmentBehavior == .never)
        #expect(resolvedMetrics.obscuredInsets == UIEdgeInsets(top: 21, left: 0, bottom: 34, right: 0))
        #expect(metricsProvider.callCount > 0)
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

@MainActor
private final class ManagedViewportStaticMetricsSource: ViewportMetricsSource {
    private(set) var callCount = 0

    func makeViewportMetrics(
        in hostViewController: UIViewController,
        webView: WKWebView,
        keyboardOverlapHeight: CGFloat,
        inputAccessoryOverlapHeight: CGFloat
    ) -> ViewportMetrics {
        callCount += 1
        return ViewportMetrics(
            safeArea: .init(
                viewport: .zero,
                legacyFallbackBaseline: .zero
            ),
            topObscuredHeight: 21,
            bottomObscuredHeight: 34,
            keyboardOverlapHeight: keyboardOverlapHeight,
            inputAccessoryOverlapHeight: inputAccessoryOverlapHeight,
            bottomChromeMode: .normal
        )
    }
}
#endif
