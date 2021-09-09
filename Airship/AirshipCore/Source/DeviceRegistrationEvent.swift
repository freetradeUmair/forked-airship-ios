/* Copyright Airship and Contributors */

/**
 * @note For Interrnal use only :nodoc:
 */
@objc(UADeviceRegistrationEvent)
public class DeviceRegistrationEvent : NSObject, Event {
    
    @objc
    public init(channel: ChannelProtocol?,
                push: PushProtocol?,
                privacyManager: PrivacyManager?) {
         
        var data: [AnyHashable : Any] = [:]
        if privacyManager?.isEnabled(.push) == true {
            data["device_token"] = push?.deviceToken
        }

        data["channel_id"] = channel?.identifier

        self._data = data
    }
    
    @objc
    public override convenience init() {
        self.init(channel: Airship.channel, push: Airship.push, privacyManager: Airship.shared.privacyManager)
    }
    
    @objc
    public var priority: UAEventPriority {
        get {
            return .normal
        }
    }
    
    @objc
    public var eventType : String {
        get {
            return "device_registration"
        }
    }

    private let _data : [AnyHashable : Any]

    @objc
    public var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }
}