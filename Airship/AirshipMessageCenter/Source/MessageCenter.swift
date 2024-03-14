/* Copyright Airship and Contributors */

import Foundation
import Combine

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Delegate protocol for receiving callbacks related to message center.
@objc(UAMessageCenterDisplayDelegate)
public protocol MessageCenterDisplayDelegate {

    /// Called when a message is requested to be displayed.
    ///
    /// - Parameters:
    ///   - messageID: The message ID.
    @objc(displayMessageCenterForMessageID:)
    func displayMessageCenter(messageID: String)

    /// Called when the message center is requested to be displayed.
    @objc
    func displayMessageCenter()

    /// Called when the message center is requested to be dismissed.
    @objc
    func dismissMessageCenter()
}

/// Airship Message Center module.
@objc(UAMessageCenter)
public class MessageCenter: NSObject, ObservableObject {

    /// Message center display delegate.
    @objc
    public var displayDelegate: MessageCenterDisplayDelegate?

    private let privacyManager: AirshipPrivacyManager
    private let disableHelper: ComponentDisableHelper

    /// Message center inbox.
    @objc
    public var inbox: MessageCenterInbox

    private var currentDisplay: Disposable?

    /// The message center controller.
    @Published
    @objc
    public var controller: MessageCenterController

    /// Default message center theme. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    /// you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    public var theme: MessageCenterTheme?

    /// Loads a Message center theme from a plist file. If you are embedding the MessageCenterView directly
    /// you should pass the theme in through the view extension `.messageCenterTheme(_:)`.
    /// - Parameters:
    ///     - plist: The name of the plist in the bundle.
    @objc
    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try MessageCenterTheme.fromPlist(plist)
    }

    private var enabled: Bool {
        return self.isComponentEnabled
            && self.privacyManager.isEnabled(.messageCenter)
    }

    /// The shared MessageCenter instance. `Airship.takeOff` must be called before accessing this instance.
    @objc
    public static var shared: MessageCenter {
        return Airship.requireComponent(ofType: MessageCenter.self)
    }
    
    /// Default message center predicate. Only applies to the OOTB Message Center. If you are embedding the MessageCenterView directly
    ///  you should pass the predicate in through the view extension `.messageCenterPredicate(_:)`.
    @objc
    public var predicate: MessageCenterPredicate?
    
    init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        privacyManager: AirshipPrivacyManager,
        notificationCenter: NotificationCenter = NotificationCenter.default,
        inbox: MessageCenterInbox,
        controller: MessageCenterController
    ) {
        self.inbox = inbox
        self.privacyManager = privacyManager
        self.theme = MessageCenterThemeLoader.defaultPlist()
        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "MessageCenter"
        )
        self.controller = controller
        
        super.init()

        if let plist = config.messageCenterStyleConfig {
            do {
                try setThemeFromPlist(plist)
            } catch {
                AirshipLogger.error("Failed to load Message Center \(plist) theme \(error) ")
            }
        }

        notificationCenter.addObserver(
            forName: AirshipPrivacyManager.changeEvent,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.updateEnableState()
        }

        self.disableHelper.onChange = {
            self.updateEnableState()
        }

        self.updateEnableState()
    }

    convenience init(
        dataStore: PreferenceDataStore,
        config: RuntimeConfig,
        channel: AirshipChannel,
        privacyManager: AirshipPrivacyManager,
        workManager: AirshipWorkManagerProtocol
    ) {

        let controller = MessageCenterController()
        let inbox = MessageCenterInbox(
            with: config,
            dataStore: dataStore,
            channel: channel,
            workManager: workManager, 
            controller: controller
        )

        self.init(
            dataStore: dataStore,
            config: config,
            privacyManager: privacyManager,
            inbox: inbox,
            controller: controller
        )
    }

    /// Display the message center.
    @objc
    @MainActor
    public func display() {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.")
            return
        }

        guard let displayDelegate = self.displayDelegate else {
            AirshipLogger.trace("Launching OOTB message center")
            showDefaultMessageCenter()
            self.controller.navigate(messageID: nil)
            return
        }

        AirshipLogger.trace("Message center opened through delegate")
        displayDelegate.displayMessageCenter()
    }

    /// Display the given message with animation.
    /// - Parameters:
    ///     - messageID:  The messageID of the message.
    @objc(displayWithMessageID:)
    @MainActor
    public func display(messageID: String) {
        guard self.enabled else {
            AirshipLogger.warn("Message center disabled. Unable to display.")
            return
        }

        guard let displayDelegate = self.displayDelegate else {
            AirshipLogger.trace("Launching OOTB message center")
            showDefaultMessageCenter()
            self.controller.navigate(messageID: messageID)
            return
        }

        displayDelegate.displayMessageCenter(
            messageID: messageID
        )

    }

    /// Dismiss the message center.
    @objc
    public func dismiss() {
        if let displayDelegate = self.displayDelegate {
            displayDelegate.dismissMessageCenter()
        } else {
            Task { @MainActor in
                self.dismissDefaultMessageCenter()
            }
        }
    }

    private func updateEnableState() {
        self.inbox.enabled = self.enabled
    }
}

extension MessageCenter: AirshipComponent, PushableComponent {

    private static let kUARichPushMessageIDKey = "_uamid"

    // MARK: Component

    public var isComponentEnabled: Bool {
        get {
            return self.disableHelper.enabled
        }

        set {
            self.disableHelper.enabled = newValue
        }
    }

    @MainActor
    func deepLink(deepLink: URL) -> Bool {
        if !(deepLink.scheme == Airship.deepLinkScheme) {
            return false
        }

        if !(deepLink.host == "message_center") {
            return false
        }

        if deepLink.path.hasPrefix("/message/") {
            if deepLink.pathComponents.count != 3 {
                return false
            }
            let messageID: String = deepLink.pathComponents[2]
            self.display(messageID: messageID)
        } else {
            if (deepLink.path.count != 0) && !(deepLink.path == "/") {
                return false
            }

            self.display()
        }

        return true
    }

    // MARK: PushableComponent

    @MainActor
    public func receivedRemoteNotification(
        _ notification: [AnyHashable: Any],
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {

        guard
            let messageID = MessageCenterMessage.parseMessageID(
                userInfo: notification
            )
        else {
            completionHandler(.noData)
            return
        }

        Task {
            let result = await self.inbox.refreshMessages()

            if !result {
                completionHandler(.failed)
                return
            }

            let message = await self.inbox.message(forID: messageID)

            guard message != nil else {
                completionHandler(.noData)
                return
            }
            completionHandler(.newData)
        }
    }
}

extension MessageCenter {

    @MainActor
    fileprivate func showDefaultMessageCenter() {
        guard self.currentDisplay == nil else {
            return
        }

        guard let scene = try? AirshipUtils.findWindowScene() else {
            AirshipLogger.error(
                "Unable to display message center, missing scene."
            )
            return
        }

        var window: UIWindow? = UIWindow(windowScene: scene)

        self.currentDisplay = Disposable {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        let viewController = MessageCenterViewControllerFactory.make(
            theme: theme, 
            predicate: predicate,
            controller: self.controller
        ) {
            self.currentDisplay?.dispose()
            self.currentDisplay = nil
        }

        window?.isHidden = false
        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = viewController
    }

    @MainActor
    fileprivate func dismissDefaultMessageCenter() {
        self.currentDisplay?.dispose()
        self.currentDisplay = nil
    }
}
