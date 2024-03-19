/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

protocol InAppMessageAnalyticsProtocol: AnyObject, Sendable {
    @MainActor
    func recordEvent(
        _ event: InAppEvent,
        layoutContext: ThomasLayoutContext?
    )
}

final class LoggingInAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    func recordEvent(_ event: InAppEvent, layoutContext: ThomasLayoutContext?) {
        if let layoutContext = layoutContext {
            print("Event added: \(event) context: \(layoutContext)")
        } else {
            print("Event added: \(event)")
        }
    }
    
    func recordImpression() {
        print("Impression recorded")
    }
}

final class InAppMessageAnalytics: InAppMessageAnalyticsProtocol {
    private let preparedScheduleInfo: PreparedScheduleInfo
    private let messageID: InAppEventMessageID
    private let source: InAppEventSource
    private let renderedLocale: AirshipJSON?
    private let eventRecorder: InAppEventRecorderProtocol
    private let isReportingEnabled: Bool
    private let date: AirshipDateProtocol

    private let historyStore: MessageDisplayHistoryStoreProtocol
    private let displayImpressionRule: InAppDisplayImpressionRule

    private let displayHistory: AirshipMainActorValue<MessageDisplayHistory>
    private let displayContext: AirshipMainActorValue<InAppEventContext.Display>

    init(
        preparedScheduleInfo: PreparedScheduleInfo,
        message: InAppMessage,
        displayImpressionRule: InAppDisplayImpressionRule,
        eventRecorder: InAppEventRecorderProtocol,
        historyStore: MessageDisplayHistoryStoreProtocol,
        displayHistory: MessageDisplayHistory,
        date: AirshipDateProtocol = AirshipDate.shared
    ) {
        self.preparedScheduleInfo = preparedScheduleInfo
        self.messageID = Self.makeMessageID(
            message: message,
            scheduleID: preparedScheduleInfo.scheduleID,
            campaigns: preparedScheduleInfo.campaigns
        )
        self.source = Self.makeEventSource(message: message)
        self.renderedLocale = message.renderedLocale
        self.eventRecorder = eventRecorder
        self.isReportingEnabled = message.isReportingEnabled ?? true
        self.displayImpressionRule = displayImpressionRule
        self.historyStore = historyStore
        self.date = date

        self.displayHistory = AirshipMainActorValue(displayHistory)

        self.displayContext = AirshipMainActorValue(
            InAppEventContext.Display(
                triggerSessionID: preparedScheduleInfo.triggerSessionID,
                isFirstDisplay: displayHistory.lastDisplay == nil,
                isFirstDisplayTriggerSessionID: preparedScheduleInfo.triggerSessionID != displayHistory.lastDisplay?.triggerSessionID
            )
        )
    }

    func recordEvent(
        _ event: InAppEvent,
        layoutContext: ThomasLayoutContext?
    ) {
        let now = self.date.now

        if event is InAppDisplayEvent {
            if let lastDisplay = displayHistory.value.lastDisplay {
                if self.preparedScheduleInfo.triggerSessionID == lastDisplay.triggerSessionID {
                    self.displayContext.update { value in
                        value.isFirstDisplay = false
                        value.isFirstDisplayTriggerSessionID = false
                    }
                } else {
                    self.displayContext.update { value in
                        value.isFirstDisplay = false
                    }
                }
            }

            if (recordImpression(date: now)) {
                self.displayHistory.update { value in
                    value.lastImpression = MessageDisplayHistory.LastImpression(
                        date: now,
                        triggerSessionID: self.preparedScheduleInfo.triggerSessionID
                    )
                }
            }


            self.displayHistory.update { value in
                value.lastDisplay = MessageDisplayHistory.LastDisplay(
                    triggerSessionID: self.preparedScheduleInfo.triggerSessionID
                )
            }


            self.historyStore.set(displayHistory.value, scheduleID: preparedScheduleInfo.scheduleID)
        }


        guard self.isReportingEnabled else { return }

        let data = InAppEventData(
            event: event, 
            context: InAppEventContext.makeContext(
                reportingContext: self.preparedScheduleInfo.reportingContext,
                experimentsResult: self.preparedScheduleInfo.experimentResult,
                layoutContext: layoutContext,
                displayContext: self.displayContext.value
            ),
            source: self.source,
            messageID: self.messageID,
            renderedLocale: self.renderedLocale
        )

        self.eventRecorder.recordEvent(inAppEventData: data)
    }

    @MainActor
    var shouldRecordImpression: Bool {
        guard
            let lastImpression = displayHistory.value.lastImpression,
            lastImpression.triggerSessionID == self.preparedScheduleInfo.triggerSessionID
        else {
            return true
        }

        switch (self.displayImpressionRule) {
        case .interval(let interval):
            return self.date.now.timeIntervalSince(lastImpression.date) >= interval
        case .once:
            return false
        }
    }

    @MainActor
    private func recordImpression(date: Date) -> Bool {
        guard shouldRecordImpression else { return false }
        guard let productID = self.preparedScheduleInfo.productID else { return false }

        let event = AirshipMeteredUsageEvent(
            eventID: UUID().uuidString,
            entityID: self.messageID.identifier,
            usageType: .inAppExperienceImpression,
            product: productID,
            reportingContext: self.preparedScheduleInfo.reportingContext,
            timestamp: date,
            contactID: self.preparedScheduleInfo.contactID
        )
        self.eventRecorder.recordImpressionEvent(event)

        return true
    }

    private static func makeMessageID(
        message: InAppMessage,
        scheduleID: String,
        campaigns: AirshipJSON?
    ) -> InAppEventMessageID {
        switch (message.source ?? .remoteData) {
        case .appDefined: return .appDefined(identifier: scheduleID)
        case .remoteData: return .airship(identifier: scheduleID, campaigns: campaigns)
        case .legacyPush: return .legacy(identifier: scheduleID)
        }
    }

    private static func makeEventSource(
        message: InAppMessage
    ) -> InAppEventSource {
        switch (message.source ?? .remoteData) {
        case .appDefined: return .appDefined
        case .remoteData: return .airship
        case .legacyPush: return .airship
        }
    }
}

