/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipAutomation
import AirshipCore

final class AutomationPreparerTest: XCTestCase {

    private let actionPreparer: TestPreparerDelegate<AirshipJSON, AirshipJSON> = TestPreparerDelegate()
    private let messagePreparer: TestPreparerDelegate<InAppMessage, PreparedInAppMessageData> = TestPreparerDelegate()
    private let remoteDataAccess: TestRemoteDataAccess = TestRemoteDataAccess()
    private let deferredResolver: TestDeferredResolver = TestDeferredResolver()
    private let experiments: TestExperimentDataProvider = TestExperimentDataProvider()
    private let frequencyLimits: TestFrequencyLimitManager = TestFrequencyLimitManager()
    private let audienceChecker: TestAudienceChecker = TestAudienceChecker()
    private var preparer: AutomationPreparer!

    private let triggerContext = AirshipTriggerContext(type: "some type", goal: 10, event: .null)

    private var preparedMessageData: PreparedInAppMessageData!
    private var runtimeConfig: RuntimeConfig?

    @MainActor
    override func setUp() async throws {
        self.preparedMessageData = PreparedInAppMessageData(
            message: InAppMessage(
                name: "some name",
                displayContent: .custom(.string("custom"))
            ),
            displayAdapter: TestDisplayAdapter(),
            displayCoordinator: TestDisplayCoordinator()
        )

        let config = AirshipConfig()
        config.requireInitialRemoteConfigEnabled = false
        self.runtimeConfig = RuntimeConfig(
            config: config,
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        
        self.preparer = AutomationPreparer(
            actionPreparer: actionPreparer,
            messagePreparer: messagePreparer,
            deferredResolver: deferredResolver,
            frequencyLimits: frequencyLimits,
            audienceChecker: audienceChecker,
            experiments: experiments,
            remoteDataAccess: remoteDataAccess,
            config: self.runtimeConfig!,
            deviceInfoProviderFactory: { contactID in
            TestDeviceInfoProvider(contactID: contactID)
        })
    
    }

    func testRequiresUpdate() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        self.remoteDataAccess.requiresUpdateBlock = { schedule in
            XCTAssertEqual(automationSchedule, schedule)
            return true
        }

        self.remoteDataAccess.waitFullRefreshBlock = { schedule in
            XCTAssertEqual(automationSchedule, schedule)
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )
        
        XCTAssertTrue(prepareResult.isInvalidate)
    }

    func testBestEfforRefreshNotCurrent() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            )
        )

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { schedule in
            XCTAssertEqual(automationSchedule, schedule)
            return false
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(prepareResult.isInvalidate)
    }

    func testFrequencyLimitOverLimit() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        let checker = TestFrequencyChecker()
        await checker.setIsOverLimit(true)

        await self.frequencyLimits.setCheckerBlock { constraintIDs in
            XCTAssertEqual(constraintIDs, automationSchedule.frequencyConstraintIDs)
            return checker
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(prepareResult.isSkipped)
    }

    func testAudienceMismatchSkip() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .skip
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, provider in
            XCTAssertEqual(audience, automationSchedule.audience?.audienceSelector)
            XCTAssertEqual(created, automationSchedule.created)
            return false
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(prepareResult.isSkipped)
    }
    
    func testAudienceMismatchPenalize() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, _ in
            XCTAssertEqual(audience, automationSchedule.audience?.audienceSelector)
            XCTAssertEqual(created, automationSchedule.created)
            return false
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(prepareResult.isPenalize)
    }

    func testAudienceMismatchCancel() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .cancel
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return nil
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { audience, created, _ in
            XCTAssertEqual(audience, automationSchedule.audience?.audienceSelector)
            XCTAssertEqual(created, automationSchedule.created)
            return false
        }

        let prepareResult = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(prepareResult.isCancelled)
    }

    func testContactIDAudienceChecks() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            triggers: [],
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }
        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            let contactID = await provider.stableContactID
            XCTAssertEqual("contact ID", contactID)
            return false
        }

        let _ = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )
    }

    func testPrepareMessage() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            XCTAssertEqual(.inAppMessage(message), automationSchedule.data)
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(automationSchedule.campaigns, info.campaigns)
            XCTAssertEqual("contact ID", info.contactID)

            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(automationSchedule.identifier, prepared.info.scheduleID)
        XCTAssertEqual(automationSchedule.campaigns, prepared.info.campaigns)
        XCTAssertEqual(prepared.data, .inAppMessage(preparedData))
        XCTAssertNotNil(prepared.frequencyChecker)
    }

    func testPrepareInvalidMessage() async throws {
        let invalidBanner = InAppMessageDisplayContent.Banner(
            heading: nil,
            body: nil,
            media: nil,
            buttons: nil,
            buttonLayoutType: .stacked,
            template: .mediaLeft,
            backgroundColor: InAppMessageColor(hexColorString: ""),
            dismissButtonColor:  InAppMessageColor(hexColorString: ""),
            borderRadius: 5,
            duration: 100.0,
            placement: .top
        )

        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .banner(invalidBanner))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            XCTAssertEqual(.inAppMessage(message), automationSchedule.data)
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(automationSchedule.campaigns, info.campaigns)
            XCTAssertEqual("contact ID", info.contactID)

            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(result.isSkipped)
    }

    func testPrepareActions() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(
                AirshipJSON.string("actions payload")
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }


        self.actionPreparer.prepareBlock = { actions, info in
            XCTAssertEqual(.actions(actions), automationSchedule.data)
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(automationSchedule.campaigns, info.campaigns)
            XCTAssertEqual("contact ID", info.contactID)
            return actions
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(automationSchedule.identifier, prepared.info.scheduleID)
        XCTAssertEqual(automationSchedule.campaigns, prepared.info.campaigns)
        XCTAssertEqual(prepared.data, .actions(AirshipJSON.string("actions payload")))
        XCTAssertNotNil(prepared.frequencyChecker)
    }

    func testPrepareDeferredActions() async throws {
        let actions = try! AirshipJSON.wrap(["some": "action"])
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .deferred(
                DeferredAutomationData(
                    url: URL(string: "example://")!,
                    retryOnTimeOut: false,
                    type: .actions
                )
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        self.deferredResolver.onData = { request in
            let data = try! AirshipJSON.wrap([
                "audience_match": true,
                "actions": actions
            ]).toData()
            return .success(data)
        }
        
        self.actionPreparer.prepareBlock = { actionsPayload, info in
            XCTAssertEqual(actionsPayload, actions)
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(automationSchedule.campaigns, info.campaigns)
            XCTAssertEqual("contact ID", info.contactID)
            return actions
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(automationSchedule.identifier, prepared.info.scheduleID)
        XCTAssertEqual(automationSchedule.campaigns, prepared.info.campaigns)
        XCTAssertEqual(prepared.data, .actions(actions))
        XCTAssertNotNil(prepared.frequencyChecker)
    }

    func testPrepareDeferredMessage() async throws {
        let message = InAppMessage(
            name: "some name",
            displayContent: .custom(.string("custom")),
            source: .remoteData
        )

        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .deferred(
                DeferredAutomationData(
                    url: URL(string: "example://")!,
                    retryOnTimeOut: false,
                    type: .inAppMessage
                )
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        self.deferredResolver.onData = { request in
            let data = try! AirshipJSON.wrap([
                "audience_match": true,
                "message": message
            ]).toData()
            return .success(data)
        }

        let preparedData = self.preparedMessageData!
        self.messagePreparer.prepareBlock = { inAppMessage, info in
            XCTAssertEqual(inAppMessage, message)
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(automationSchedule.campaigns, info.campaigns)
            XCTAssertEqual("contact ID", info.contactID)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(automationSchedule.identifier, prepared.info.scheduleID)
        XCTAssertEqual(automationSchedule.campaigns, prepared.info.campaigns)
        XCTAssertNotNil(prepared.frequencyChecker)
    }

    func testPrepareDeferredAudienceMismatchResult() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .deferred(
                DeferredAutomationData(
                    url: URL(string: "example://")!,
                    retryOnTimeOut: false,
                    type: .inAppMessage
                )
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .skip
            )
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        self.deferredResolver.onData = { request in
            let data = try! AirshipJSON.wrap([
                "audience_match": false
            ]).toData()
            return .success(data)
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        XCTAssertTrue(result.isSkipped)
    }

    func testExperiements() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            frequencyConstraintIDs: ["constraint"]
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let checker = TestFrequencyChecker()
        await self.frequencyLimits.setCheckerBlock { _ in
            return checker
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            XCTAssertEqual(.inAppMessage(message), automationSchedule.data)
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(automationSchedule.campaigns, info.campaigns)
            XCTAssertEqual("contact ID", info.contactID)

            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertEqual(automationSchedule.identifier, prepared.info.scheduleID)
        XCTAssertEqual(automationSchedule.campaigns, prepared.info.campaigns)
        XCTAssertEqual(prepared.data, .inAppMessage(preparedData))
        XCTAssertNotNil(prepared.frequencyChecker)
    }

    func testExperiments() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns"),
            messageType: "some message type"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let experimentResult = ExperimentResult(
            channelID: "some channel",
            contactID: "contact ID",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("reporting")]
        )

        self.experiments.onEvaluate = { info, provider in
            let contactID = await provider.stableContactID
            XCTAssertEqual(
                info,
                MessageInfo(
                    messageType: automationSchedule.messageType!,
                    campaigns: automationSchedule.campaigns
                )
            )
            XCTAssertEqual(contactID, "contact ID")
            return experimentResult
        }
        
        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(experimentResult, info.experimentResult)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }
        XCTAssertEqual(experimentResult, prepared.info.experimentResult)
    }

    func testExperimentsDefaultMessageType() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            campaigns: .string("campaigns")
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        let experimentResult = ExperimentResult(
            channelID: "some channel",
            contactID: "contact ID",
            isMatch: true,
            reportingMetadata: [AirshipJSON.string("reporting")]
        )

        self.experiments.onEvaluate = { info, provider in
            let contactID = await provider.stableContactID
            XCTAssertEqual(
                info,
                MessageInfo(
                    messageType: "transactional",
                    campaigns: automationSchedule.campaigns
                )
            )
            XCTAssertEqual(contactID, "contact ID")
            return experimentResult
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            XCTAssertEqual(automationSchedule.identifier, info.scheduleID)
            XCTAssertEqual(experimentResult, info.experimentResult)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }
        XCTAssertEqual(experimentResult, prepared.info.experimentResult)
    }

    func testByPassExperiments() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .inAppMessage(
                InAppMessage(name: "name", displayContent: .custom(.null))
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            bypassHoldoutGroups: true,
            campaigns: .string("campaigns"),
            messageType: "some message type"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }
        self.experiments.onEvaluate = { info, provider in
            XCTFail()
            return nil
        }

        let preparedData = self.preparedMessageData!

        self.messagePreparer.prepareBlock = { message, info in
            XCTAssertNil(info.experimentResult)
            return preparedData
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertNil(prepared.info.experimentResult)
    }

    func testByPassExperimentsActions() async throws {
        let automationSchedule = AutomationSchedule(
            identifier: UUID().uuidString,
            data: .actions(
                AirshipJSON.string("payload")
            ),
            triggers: [],
            created: Date(),
            lastUpdated: Date(),
            audience: AutomationAudience(
                audienceSelector: DeviceAudienceSelector(),
                missBehavior: .penalize
            ),
            bypassHoldoutGroups: false, // even if false
            campaigns: .string("campaigns"),
            messageType: "some message type"
        )

        self.remoteDataAccess.contactIDBlock = { _ in
            return "contact ID"
        }

        self.remoteDataAccess.requiresUpdateBlock = { _ in
            return false
        }

        self.remoteDataAccess.bestEffortRefreshBlock = { _ in
            return true
        }

        self.audienceChecker.onEvaluate = { _, _, provider in
            return true
        }

        self.experiments.onEvaluate = { info, provider in
            XCTFail()
            return nil
        }

        self.actionPreparer.prepareBlock = { actions, info in
            XCTAssertNil(info.experimentResult)
            return actions
        }

        let result = await self.preparer.prepare(
            schedule: automationSchedule,
            triggerContext: triggerContext
        )

        guard case .prepared(let prepared) = result else {
            XCTFail()
            return
        }

        XCTAssertNil(prepared.info.experimentResult)
    }
}


final class TestPreparerDelegate<In: Sendable, Out: Sendable>: AutomationPreparerDelegate, @unchecked Sendable {
    typealias PrepareDataIn = In
    typealias PrepareDataOut = Out

    var cancelledCalled: Bool = false
    var cancelledBlock: (@Sendable (String) async -> Void)?

    func cancelled(scheduleID: String) async {
        cancelledCalled = true
        await cancelledBlock!(scheduleID)
    }

    var prepareCalled: Bool = false
    var prepareBlock: (@Sendable (In, PreparedScheduleInfo) async -> Out)?

    func prepare(data: In, preparedScheduleInfo: PreparedScheduleInfo) async throws -> Out {
        prepareCalled = true
        return await prepareBlock!(data, preparedScheduleInfo)
    }
}




extension SchedulePrepareResult {
    var isInvalidate: Bool {
        switch (self) {
        case .invalidate: return true
        default: return false
        }
    }

    var isPrepared: Bool {
        switch (self) {
        case .prepared(_): return true
        default: return false
        }
    }

    var isCancelled: Bool {
        switch (self) {
        case .cancel: return true
        default: return false
        }
    }

    var isSkipped: Bool {
        switch (self) {
        case .skip: return true
        default: return false
        }
    }

    var isPenalize: Bool {
        switch (self) {
        case .penalize: return true
        default: return false
        }
    }
}


fileprivate final class TestDeviceInfoProvider: AudienceDeviceInfoProvider, @unchecked Sendable {
    var sdkVersion: String = "1.0.0"


    var isAirshipReady: Bool = false

    var tags: Set<String> = Set()

    var channelID: String? = UUID().uuidString

    var locale: Locale = Locale.current

    var appVersion: String?

    var permissions: [AirshipCore.AirshipPermission : AirshipCore.AirshipPermissionStatus] = [:]

    var isUserOptedInPushNotifications: Bool = false

    var analyticsEnabled: Bool = false

    var installDate: Date = Date()

    var stableContactID: String

    init(contactID: String?) {
        self.stableContactID = contactID ?? UUID().uuidString
    }
}

