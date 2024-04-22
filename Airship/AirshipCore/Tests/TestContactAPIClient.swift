import Foundation

@testable import AirshipCore

class TestContactAPIClient: ContactsAPIClientProtocol, @unchecked Sendable {

    var resolveCallback:
        ((String, String?, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var identifyCallback:
        ((String, String, String?, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var resetCallback:
        ((String, String?) async throws -> AirshipHTTPResponse<ContactIdentifyResult>)?

    var updateCallback:
        ((String, [TagGroupUpdate]?, [AttributeUpdate]?, [ScopedSubscriptionListUpdate]?) async throws -> AirshipHTTPResponse<Void>)?

    var associateChannelCallback:
        ((String, String, ChannelType, RegistrationOptions) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    var registerEmailCallback:
        ((String, String, EmailRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    var registerSMSCallback:
        ((String, String, SMSRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<AssociatedChannel>)?

    var validateSMSCallback:
        ((String, String, String) async throws -> AirshipHTTPResponse<Bool>)?

    var registerOpenCallback:
        ((String, String, OpenRegistrationOptions, Locale) async throws -> AirshipHTTPResponse<AssociatedChannel>)?
    
    var optOutChannelCallback: ((String, String) async throws -> AirshipHTTPResponse<Bool>)?

    init() {}

    public func resolve(
        channelID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await resolveCallback!(channelID, contactID, possiblyOrphanedContactID)
    }

    public func identify(
        channelID: String,
        namedUserID: String,
        contactID: String?,
        possiblyOrphanedContactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await identifyCallback!(channelID, namedUserID, contactID, possiblyOrphanedContactID)
    }

    public func reset(
        channelID: String,
        possiblyOrphanedContactID: String?
    ) async throws -> AirshipHTTPResponse<ContactIdentifyResult> {
        return try await resetCallback!(channelID, possiblyOrphanedContactID)
    }

    public func update(
        contactID: String,
        tagGroupUpdates: [TagGroupUpdate]?,
        attributeUpdates: [AttributeUpdate]?,
        subscriptionListUpdates: [ScopedSubscriptionListUpdate]?
    ) async throws -> AirshipHTTPResponse<Void> {
        return try await updateCallback!(contactID, tagGroupUpdates, attributeUpdates, subscriptionListUpdates)
    }

    public func associateChannel(
        contactID: String,
        channelID: String,
        channelType: ChannelType,
        options: RegistrationOptions
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await associateChannelCallback!(contactID, channelID, channelType, options)
    }

    public func registerEmail(
        contactID: String,
        address: String,
        options: EmailRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerEmailCallback!(contactID, address, options, locale)
    }

    public func registerSMS(
        contactID: String,
        msisdn: String,
        options: SMSRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerSMSCallback!(contactID, msisdn, options, locale)
    }

    func validateSMS(
        contactID: String,
        msisdn: String,
        sender: String
    ) async throws -> AirshipHTTPResponse<Bool> {
        return try await validateSMSCallback!(contactID, msisdn, sender)
    }
    
    public func registerOpen(
        contactID: String,
        address: String,
        options: OpenRegistrationOptions,
        locale: Locale
    ) async throws -> AirshipHTTPResponse<AssociatedChannel> {
        return try await registerOpenCallback!(contactID, address, options, locale)
    }
    
    func optOutChannel(contactID: String, channelID: String) async throws -> AirshipHTTPResponse<Bool> {
        return try await optOutChannelCallback!(contactID, channelID)
    }
}
