import XCTest

@testable
import AirshipCore


final class ContactManagerTest: XCTestCase {

    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date())
    private let channel: TestChannel = TestChannel()
    private let localeManager: TestLocaleManager = TestLocaleManager()
    private let workManager: TestWorkManager = TestWorkManager()
    private let dataStore: PreferenceDataStore = PreferenceDataStore(appKey: UUID().uuidString)
    private let apiClient: TestContactAPIClient = TestContactAPIClient()
    private var contactManager: ContactManager!

    private let anonIdentifyResponse: ContactIdentifyResult = ContactIdentifyResult(
        contact: ContactIdentifyResult.ContactInfo(
            channelAssociatedDate: AirshipUtils.parseISO8601Date(from: "2022-12-29T10:15:30.00")!,
            contactID: "some contact",
            isAnonymous: true
        ),
        token: "some token",
        tokenExpiresInMilliseconds: 3600000
    )

    private let nonAnonIdentifyResponse: ContactIdentifyResult = ContactIdentifyResult(
        contact: ContactIdentifyResult.ContactInfo(
            channelAssociatedDate: AirshipUtils.parseISO8601Date(from: "2022-12-29T10:15:30.00")!,
            contactID: "some other contact",
            isAnonymous: false
        ),
        token: "some other token",
        tokenExpiresInMilliseconds: 3600000
    )

    override func setUp() async throws {
        self.localeManager.currentLocale = Locale(identifier: "fr-CA")

        self.contactManager = ContactManager(
            dataStore: self.dataStore,
            channel: self.channel,
            localeManager: self.localeManager,
            apiClient: self.apiClient,
            date: self.date,
            workManager: self.workManager,
            internalIdentifyRateLimit: 0.0
        )

        await self.contactManager.setEnabled(enabled: true)
        self.channel.identifier = "some channel"
    }

    func testEnableEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: false)
        XCTAssertTrue(self.workManager.workRequests.isEmpty)

        await self.contactManager.addOperation(.resolve)

        await self.contactManager.setEnabled(enabled: false)
        XCTAssertTrue(self.workManager.workRequests.isEmpty)

        await self.contactManager.setEnabled(enabled: true)
        XCTAssertFalse(self.workManager.workRequests.isEmpty)
    }

    func testAddOperationEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: true)
        XCTAssertTrue(self.workManager.workRequests.isEmpty)

        await self.contactManager.addOperation(.resolve)
        XCTAssertFalse(self.workManager.workRequests.isEmpty)
    }

    func testAddSkippableOperationEnqueuesWork() async throws {
        await self.contactManager.setEnabled(enabled: true)
        await self.contactManager.addOperation(.resolve)

        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)
        self.workManager.workRequests.removeAll()

        await self.contactManager.addOperation(.reset)
        XCTAssertFalse(self.workManager.workRequests.isEmpty)
    }

    func testRateLimitConfig() async throws {
        let rateLimits = self.workManager.rateLimits
        XCTAssertEqual(2, rateLimits.count)

        let updateRule = rateLimits[ContactManager.updateRateLimitID]!
        XCTAssertEqual(1, updateRule.rate)
        XCTAssertEqual(0.5, updateRule.timeInterval, accuracy: 0.01)


        let identityRule = rateLimits[ContactManager.identityRateLimitID]!
        XCTAssertEqual(1, identityRule.rate)
        XCTAssertEqual(5.0, identityRule.timeInterval, accuracy: 0.01)
    }

    func testResolve() async throws {
        await self.contactManager.addOperation(.resolve)

        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .success)
        await fulfillmentCompat(of: [resolve])

        let contactInfo = await self.contactManager.currentContactIDInfo()
        XCTAssertEqual(anonIdentifyResponse.contact.contactID, contactInfo?.contactID)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: self.anonIdentifyResponse.contact.contactID,
                    isStable: true,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    func testResolvedFailed() async throws {
        await self.contactManager.addOperation(.resolve)
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 500,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .failure)
    }

    func testVerify() async throws {
        await self.contactManager.addOperation(.verify(self.date.now))

        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .success)
        await fulfillmentCompat(of: [resolve])

        let contactInfo = await self.contactManager.currentContactIDInfo()
        XCTAssertEqual(anonIdentifyResponse.contact.contactID, contactInfo?.contactID)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: self.anonIdentifyResponse.contact.contactID,
                    isStable: true,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    func testRequiredVerify() async throws {
        // Resolve is called first if we do not have a valid token
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        await self.contactManager.addOperation(.resolve)
        _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        await fulfillmentCompat(of: [resolve])

        await self.contactManager.addOperation(.verify(self.date.now + 1, required: true))

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: true,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: false,
                        resolveDate: self.date.now
                    )
                )
            ]
        )
    }

    func testVerifyFailed() async throws {
        await self.contactManager.addOperation(.verify(self.date.now))
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 500,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .failure)
    }

    func testResolvedFailedClientError() async throws {
        await self.contactManager.addOperation(.resolve)
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .success)
    }

    func testIdentify() async throws {
        await self.contactManager.addOperation(.identify("some named user"))
        await self.verifyUpdates([.namedUserUpdate("some named user")])

        // Resolve is called first if we do not have a valid token
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let identify = XCTestExpectation()
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertEqual("some named user", namedUserID)
            XCTAssertEqual(self.anonIdentifyResponse.contact.contactID, contactID)
            identify.fulfill()
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .success)
        await fulfillmentCompat(of: [resolve, identify])

        let contactInfo = await self.contactManager.currentContactIDInfo()
        XCTAssertEqual(nonAnonIdentifyResponse.contact.contactID, contactInfo?.contactID)

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: false,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.nonAnonIdentifyResponse.contact.contactID,
                        isStable: true,
                        resolveDate: self.date.now
                    )
                ),
            ]
        )
    }

    func testIdentifyFailed() async throws {
        await self.contactManager.addOperation(.identify("some named user"))

        // Resolve is called first if we do not have a valid token
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 500,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .failure)
    }

    func testIdentifyFailedClientError() async throws {
        await self.contactManager.addOperation(.identify("some named user"))

        // Resolve is called first if we do not have a valid token
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 400,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .success)
    }

    func testReset() async throws {
        await self.contactManager.addOperation(.reset)

        // Resolve is called first if we do not have a valid token
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            XCTAssertNil(contactID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let reset = XCTestExpectation()
        self.apiClient.resetCallback = { channelID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            reset.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        XCTAssertEqual(result, .success)
        await fulfillmentCompat(of: [resolve, reset])

        await self.verifyUpdates(
            [
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.nonAnonIdentifyResponse.contact.contactID,
                        isStable: false,
                        resolveDate: self.date.now
                    )
                ),
                .contactIDUpdate(
                    ContactIDInfo(
                        contactID: self.anonIdentifyResponse.contact.contactID,
                        isStable: true,
                        resolveDate: self.date.now
                    )
                )
            ]
        )
    }

    func testAuthTokenNoContactInfo() async throws {
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        let authToken = try await self.contactManager.resolveAuth(
            identifier: self.anonIdentifyResponse.contact.contactID
        )
        XCTAssertEqual(authToken, self.anonIdentifyResponse.token)

        await fulfillmentCompat(of: [resolve])

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: self.anonIdentifyResponse.contact.contactID,
                    isStable: true,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    func testAuthTokenValidTokenMismatchContactID() async throws {
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        await self.contactManager.addOperation(.resolve)
        let _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        do {
            let _ = try await self.contactManager.resolveAuth(
                identifier: "some other contactID"
            )
            XCTFail("Should throw")
        } catch {}

    }

    func testAuthTokenResolveMismatch() async throws {
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        do {
            let _ = try await self.contactManager.resolveAuth(
                identifier: "some other contactID"
            )
            XCTFail("Should throw")
        } catch {}

        await fulfillmentCompat(of: [resolve])
    }

    func testExpireAuthToken() async throws {
        let resolve = XCTestExpectation(description: "resolve contact")
        resolve.expectedFulfillmentCount = 2

        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }


        var authToken = try await self.contactManager.resolveAuth(
            identifier: self.anonIdentifyResponse.contact.contactID
        )

        await self.contactManager.authTokenExpired(token: authToken)

        authToken = try await self.contactManager.resolveAuth(
            identifier: self.anonIdentifyResponse.contact.contactID
        )

        XCTAssertEqual(authToken, self.anonIdentifyResponse.token)
    }

    func testAuthTokenFailed() async throws {
        let resolve = XCTestExpectation(description: "resolve contact")
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            XCTAssertEqual(self.channel.identifier, channelID)
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 400,
                headers: [:]
            )
        }

        do {
            let _ = try await self.contactManager.resolveAuth(
                identifier: "some contact id"
            )
            XCTFail("Should throw")
        } catch {}

        await fulfillmentCompat(of: [resolve])
    }

    func testGenerateDefaultContactInfo() async {
        var contactInfo = await self.contactManager.currentContactIDInfo()
        XCTAssertNil(contactInfo)


        await self.contactManager.generateDefaultContactIDIfNotSet()
        contactInfo = await self.contactManager.currentContactIDInfo()
        XCTAssertNotNil(contactInfo)


        XCTAssertEqual(contactInfo!.contactID.lowercased(), contactInfo!.contactID)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo!.contactID,
                    isStable: true,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    func testGenerateDefaultContactInfoLowercasedID() async {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactInfo = await self.contactManager.currentContactIDInfo()
        XCTAssertNotNil(contactInfo)
        XCTAssertEqual(contactInfo!.contactID.lowercased(), contactInfo!.contactID)
    }

    func testGenerateDefaultContactInfoAlreadySet() async throws {
        await self.contactManager.addOperation(.resolve)
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }
        let _ = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        let contactInfo = await self.contactManager.currentContactIDInfo()!

        await self.contactManager.generateDefaultContactIDIfNotSet()

        let afterGenerate = await self.contactManager.currentContactIDInfo()
        XCTAssertEqual(contactInfo, afterGenerate)
    }

    func testContactUnstablePendingReset() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactInfo = await self.contactManager.currentContactIDInfo()!

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: true,
                    resolveDate: self.date.now
                )
            )
        ])

        await self.contactManager.addOperation(.reset)

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: false,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    func testContactUnstablePendingIdentify() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactInfo = await self.contactManager.currentContactIDInfo()!

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: true,
                    resolveDate: self.date.now
                )
            )
        ])

        await self.contactManager.addOperation(.identify("something something"))

        await self.verifyUpdates([
            .contactIDUpdate(
                ContactIDInfo(
                    contactID: contactInfo.contactID,
                    isStable: false,
                    resolveDate: self.date.now
                )
            )
        ])
    }

    func testPendingUpdatesCombineOperations() async throws {
        await self.contactManager.generateDefaultContactIDIfNotSet()

        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
        ]

        let attributes = [
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now)
        ]

        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: nil,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: attributes,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: nil,
                subscriptionListsUpdates: subscriptions
            )
        )

        let contactID = await self.contactManager.currentContactIDInfo()!.contactID
        let pendingOverrides = await self.contactManager.pendingAudienceOverrides(
            contactID: contactID
        )

        XCTAssertEqual(tags, pendingOverrides.tags)
        XCTAssertEqual(attributes, pendingOverrides.attributes)
        XCTAssertEqual(subscriptions, pendingOverrides.subscriptionLists)
    }

    func testPendingUpdates() async throws {
        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add)
        ]

        let attributes = [
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now)
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now)
        ]

        await self.contactManager.generateDefaultContactIDIfNotSet()
        let contactID = await self.contactManager.currentContactIDInfo()!.contactID

        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: nil,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(.identify("some user"))
        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: attributes,
                subscriptionListsUpdates: nil
            )
        )

        await self.contactManager.addOperation(.identify("some other user"))
        await self.contactManager.addOperation(
            .update(
                tagUpdates: nil,
                attributeUpdates: nil,
                subscriptionListsUpdates: subscriptions
            )
        )


        // Since are an anon user ID, we should get the tags,
        // assume the identify will keep the same contact id,
        // get the attributes, then skip the subscriptions
        // because it will for sure be a different contact ID

        let anonUserOverrides = await self.contactManager.pendingAudienceOverrides(contactID: contactID)
        XCTAssertEqual(tags, anonUserOverrides.tags)
        XCTAssertEqual(attributes, anonUserOverrides.attributes)
        XCTAssertEqual([], anonUserOverrides.subscriptionLists)


        // If we request a stale contact ID, it should return empty overrides
        let staleOverrides = await self.contactManager.pendingAudienceOverrides(contactID: "not the current contact id")
        XCTAssertEqual([], staleOverrides.tags)
        XCTAssertEqual([], staleOverrides.attributes)
        XCTAssertEqual([], staleOverrides.subscriptionLists)
    }

    func testRegisterEmail() async throws {
        let expectedAddress = "ua@airship.com"
        let expectedOptions = EmailRegistrationOptions.options(
            transactionalOptedIn: Date(),
            properties: ["interests": "newsletter"],
            doubleOptIn: true
        )

        await self.contactManager.addOperation(
            .registerEmail(address: expectedAddress, options: expectedOptions)
        )

        // Should resolve contact first
        let resolve = XCTestExpectation()
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        let register = XCTestExpectation()
        self.apiClient.registerEmailCallback = { contactID, address, options, locale in
            XCTAssertEqual(contactID, self.anonIdentifyResponse.contact.contactID)
            XCTAssertEqual(address, expectedAddress)
            XCTAssertEqual(options, options)
            XCTAssertEqual(locale, self.localeManager.currentLocale)
            register.fulfill()
            return AirshipHTTPResponse(
                result: AssociatedChannel(
                    channelType: .email, channelID: "some channel"
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        await self.fulfillmentCompat(of: [resolve, register], timeout: 10)
    }

    func testRegisterOpen() async throws {
        let expectedAddress = "ua@airship.com"
        let expectedOptions = OpenRegistrationOptions.optIn(
            platformName: "my_platform",
            identifiers: ["model": "4"]
        )

        await self.contactManager.addOperation(
            .registerOpen(address: expectedAddress, options: expectedOptions)
        )

        // Should resolve contact first
        let resolve = XCTestExpectation()
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        let register = XCTestExpectation()
        self.apiClient.registerOpenCallback = { contactID, address, options, locale in
            XCTAssertEqual(contactID, self.anonIdentifyResponse.contact.contactID)
            XCTAssertEqual(address, expectedAddress)
            XCTAssertEqual(options, options)
            XCTAssertEqual(locale, self.localeManager.currentLocale)
            register.fulfill()
            return AirshipHTTPResponse(
                result: AssociatedChannel(
                    channelType: .open, channelID: "some channel"
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        await self.fulfillmentCompat(of: [resolve, register], timeout: 10)
    }

    func testRegisterSMS() async throws {
        let expectedAddress = "15035556789"
        let expectedOptions = SMSRegistrationOptions.optIn(senderID: "28855")

        await self.contactManager.addOperation(
            .registerSMS(msisdn: expectedAddress, options: expectedOptions)
        )

        // Should resolve contact first
        let resolve = XCTestExpectation()
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        let register = XCTestExpectation()
        self.apiClient.registerSMSCallback = { contactID, address, options, locale in
            XCTAssertEqual(contactID, self.anonIdentifyResponse.contact.contactID)
            XCTAssertEqual(address, expectedAddress)
            XCTAssertEqual(options, options)
            XCTAssertEqual(locale, self.localeManager.currentLocale)
            register.fulfill()
            return AirshipHTTPResponse(
                result: AssociatedChannel(
                    channelType: .open, channelID: "some channel"
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        await self.fulfillmentCompat(of: [resolve, register], timeout: 10)
    }

    func testAssociateChannel() async throws {
        await self.contactManager.addOperation(
            .associateChannel(channelID: "some channel", channelType: .open)
        )

        // Should resolve contact first
        let resolve = XCTestExpectation()
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        let register = XCTestExpectation()
        self.apiClient.associateChannelCallback = { contactID, address, type in
            XCTAssertEqual(contactID, self.anonIdentifyResponse.contact.contactID)
            XCTAssertEqual(address, "some channel")
            XCTAssertEqual(type, .open)
            register.fulfill()
            return AirshipHTTPResponse(
                result: AssociatedChannel(
                    channelType: .open, channelID: "some channel"
                ),
                statusCode: 200,
                headers: [:]
            )
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        await self.fulfillmentCompat(of: [resolve, register], timeout: 10)
    }

    func testUpdate() async throws {
        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add),
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .remove),
            TagGroupUpdate(group: "some group", tags: ["some other tag"], type: .remove)
        ]

        let attributes = [
            AttributeUpdate(attribute: "some other attribute", type: .set, jsonValue: .string("cool"), date: self.date.now),
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now),
            AttributeUpdate(attribute: "some attribute", type: .remove, jsonValue: .string("cool"), date: self.date.now)
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some other list", type: .subscribe, scope: .app, date: self.date.now),
            ScopedSubscriptionListUpdate(listId: "some list", type: .unsubscribe, scope: .app, date: self.date.now),
            ScopedSubscriptionListUpdate(listId: "some list", type: .subscribe, scope: .app, date: self.date.now)
        ]

        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: attributes,
                subscriptionListsUpdates: subscriptions
            )
        )

        // Should resolve contact first
        let resolve = XCTestExpectation()
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            resolve.fulfill()
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // Then register the channel
        let update = XCTestExpectation()
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionUpdates in
            XCTAssertEqual(contactID, self.anonIdentifyResponse.contact.contactID)
            XCTAssertEqual(tagUpdates, AudienceUtils.collapse(tags))
            XCTAssertEqual(attributeUpdates, AudienceUtils.collapse(attributes))
            XCTAssertEqual(subscriptionUpdates, AudienceUtils.collapse(subscriptions))
            update.fulfill()
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        let audienceCallback = XCTestExpectation()
        await self.contactManager.onAudienceUpdated { update in
            XCTAssertEqual(update.tags, AudienceUtils.collapse(tags))
            XCTAssertEqual(update.attributes, AudienceUtils.collapse(attributes))
            XCTAssertEqual(update.subscriptionLists, AudienceUtils.collapse(subscriptions))
            audienceCallback.fulfill()
        }

        let result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)

        await self.fulfillmentCompat(of: [resolve, update, audienceCallback], timeout: 10)
    }

    func testConflict() async throws {
        let tags = [
            TagGroupUpdate(group: "some group", tags: ["tag"], type: .add),
        ]

        let attributes = [
            AttributeUpdate(attribute: "some attribute", type: .set, jsonValue: .string("cool"), date: self.date.now),
        ]

        let subscriptions = [
            ScopedSubscriptionListUpdate(listId: "some list", type: .subscribe, scope: .app, date: self.date.now),
        ]

        // Adds some anon data
        await self.contactManager.addOperation(
            .update(
                tagUpdates: tags,
                attributeUpdates: attributes,
                subscriptionListsUpdates: subscriptions
            )
        )

        // resolve
        self.apiClient.resolveCallback = { channelID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.anonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        // update
        self.apiClient.updateCallback = { contactID, tagUpdates, attributeUpdates, subscriptionUpdates in
            return AirshipHTTPResponse(
                result: nil,
                statusCode: 200,
                headers: [:]
            )
        }

        // identify
        self.apiClient.identifyCallback = { channelID, namedUserID, contactID, possiblyOrphanedContactID in
            return AirshipHTTPResponse(
                result: self.nonAnonIdentifyResponse,
                statusCode: 200,
                headers: [:]
            )
        }

        var result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )

        await self.contactManager.addOperation(.identify("some named user"))

        result = try await self.workManager.launchTask(
            request: AirshipWorkRequest(
                workID: ContactManager.updateTaskID
            )
        )
        XCTAssertEqual(result, .success)


        let expctedConflictEvent =  ContactConflictEvent(
            tags: ["some group": ["tag"]],
            attributes: ["some attribute": .string("cool")],
            channels: [],
            subscriptionLists: ["some list": [.app]],
            conflictingNamedUserID: "some named user"
        )
        // resolve, update, resolve, conflict
        let conflict = await self.collectUpdates(count: 4).last
        XCTAssertEqual(conflict, .conflict(expctedConflictEvent))
    }

    private func collectUpdates(count: Int) async -> [ContactUpdate] {
        guard count > 0 else { return [] }

        var collected: [ContactUpdate] = []
        for await contactUpdate in await self.contactManager.contactUpdates {
            collected.append(contactUpdate)
            if (collected.count == count) {
                break
            }
        }

        return collected
    }

    private func verifyUpdates(_ expected: [ContactUpdate], file: StaticString = #filePath, line: UInt = #line) async {
        let collected = await self.collectUpdates(count: expected.count)
        XCTAssertEqual(collected, expected, file: file, line: line)
    }
}
