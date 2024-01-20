/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

final class AirshipLayoutDisplayAdapter: DisplayAdapter {

    private let message: InAppMessage
    private let assets: AirshipCachedAssetsProtocol
    private let networkChecker: NetworkCheckerProtocol

    init(
        message: InAppMessage,
        assets: AirshipCachedAssetsProtocol,
        networkChecker: NetworkCheckerProtocol = NetworkChecker()
    ) throws {
        self.message = message
        self.assets = assets
        self.networkChecker = networkChecker

        if case .custom(_) = message.displayContent {
            throw AirshipErrors.error("Invalid adapter for layout type")
        }
    }

    var isReady: Bool {
        let urlInfos = message.urlInfos
        let needsNetwork = urlInfos.contains { info in
            guard
                info.urlType == .image,
                let url = URL(string: info.url),
                assets.isCached(remoteURL: url)
            else {
                return true
            }
            return false
        }

        return needsNetwork ? networkChecker.isConnected : true
    }

    func waitForReady() async {
        guard await !self.isReady else {
            return
        }

        for await isConnected in await networkChecker.connectionUpdates {
            if (isConnected) {
                return
            }
        }
    }

    func display(
        scene: WindowSceneHolder,
        analytics: InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        switch (message.displayContent) {
        case .banner(_):
            // TODO
            return .finished
        case .fullscreen(let fullscreen):
            return await displayFullscreen(
                fullscreen,
                scene: scene.scene,
                analytics: analytics
            )

        case .modal(_):
            // TODO
            return .finished
        case .html(_):
            // TODO
            return .finished
        case .airshipLayout(let layout):
            return try await displayThomasLayout(
                layout,
                scene: scene.scene,
                analytics: analytics
            )
        case .custom(_):
            // This should never happen - constructor will throw
            return .finished
        }
    }

    @MainActor
    private func displayFullscreen(
        _ fullscreen: InAppMessageDisplayContent.Fullscreen,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async -> DisplayResult {
        return await withCheckedContinuation { continuation in
            let listener = InAppMessageDisplayListener(
                analytics: analytics
            ) { result in
                continuation.resume(returning: result)
            }

            let window = UIWindow.makeModalReadyWindow(scene: scene)
            let environment = InAppMessageEnvironment(
                delegate: listener,
                theme: Theme.fullScreen(FullScreenTheme()),
                imageProvider: AssetCacheImageProvider(assets: assets)
            ) {
                window.animateOut()
            }

            let rootView = InAppMessageRootView(inAppMessageEnvironment: environment) { orientation, windowSize in
                FullScreenView(displayContent: fullscreen)
            }

            let viewController = InAppMessageHostingController(rootView: rootView)
            viewController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            window.rootViewController = viewController

            window.animateIn()
        }
    }

    @MainActor
    private func displayThomasLayout(
        _ layout: AirshipLayout,
        scene: UIWindowScene,
        analytics: InAppMessageAnalyticsProtocol
    ) async throws -> DisplayResult {
        return try await withCheckedThrowingContinuation { continuation in
            let listener = ThomasDisplayListener(analytics: analytics) { result in
                continuation.resume(returning: result)
            }

            let extensions = ThomasExtensions(
                nativeBridgeExtension: InAppMessageNativeBridgeExtension(
                    message: message
                ),
                imageProvider: AssetCacheImageProvider(assets: assets)
            )

            do {
                try Thomas.display(
                    layout: layout,
                    scene: scene,
                    extensions: extensions,
                    delegate: listener
                )

                // TODO move to thomas
                listener.onDisplay()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

fileprivate class AssetCacheImageProvider : AirshipImageProvider {
    let assets: AirshipCachedAssetsProtocol
    init(assets: AirshipCachedAssetsProtocol) {
        self.assets = assets
    }

    func get(url: URL) -> AirshipImageData? {
        guard 
            let url = assets.cachedURL(remoteURL: url),
            let data = FileManager.default.contents(atPath: url.path),
            let imageData = try? AirshipImageData(data: data)
        else {
            return nil
        }

        return imageData
    }
}


private extension UIWindow {

    static func makeModalReadyWindow(
        scene: UIWindowScene
    ) -> UIWindow {
        let window: UIWindow = UIWindow(windowScene: scene)
        window.accessibilityViewIsModal = false
        window.alpha = 0
        window.makeKeyAndVisible()
        window.isUserInteractionEnabled = false
        return window
    }

    func animateIn() {
        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                self?.alpha = 1
                self?.makeKeyAndVisible()
            },
            completion: { [weak self] _ in
                self?.isUserInteractionEnabled = true
            }
        )
    }

    func animateOut() {
        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                self?.alpha = 0
            },
            completion: { [weak self] _ in
                self?.isHidden = true
                self?.isUserInteractionEnabled = false
                self?.removeFromSuperview()
            }
        )
    }
}
