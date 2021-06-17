/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
public class UAChannelCreateResponse : UAHTTPResponse {

    @objc
    public let channelID: String?

    @objc
    public init(status: Int, channelID: String?) {
        self.channelID = channelID
        super.init(status: status)
    }
}
