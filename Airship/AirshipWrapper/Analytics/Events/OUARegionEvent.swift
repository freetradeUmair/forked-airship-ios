/* Copyright Airship and Contributors */

import Foundation
import AirshipCore

/// This singleton provides an interface to the functionality provided by the Airship iOS Push API.
@objc(OUARegionEvent)
public class OUARegionEvent: NSObject {
    
    private var regionEvent: RegionEvent?
    
    @objc
    public static let eventType: String = "region_event"
    
    @objc
    public static let regionIDKey = "region_id"
    
    /**
     * Default constructor.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     * - Parameter circularRegion: The circular region info.
     * - Parameter proximityRegion: The proximity region info.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    public convenience init?(
        regionID: String,
        source: String,
        boundaryEvent: UABoundaryEvent,
        circularRegion: CircularRegion? = nil,
        proximityRegion: ProximityRegion? = nil
    ) {
        let regionEvent = RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent)
        self.init(event: regionEvent)
    }
    
    @objc
    public init(event: RegionEvent?) {
        self.regionEvent = event
    }
    
    /**
     * Factory method for creating a region event.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    @objc(regionEventWithRegionID:source:boundaryEvent:)
    public class func regionEvent(
        regionID: String,
        source: String,
        boundaryEvent: OUABoundaryEvent
    ) -> OUARegionEvent {
        let regionEvent = RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent.event)
        return OUARegionEvent(event: regionEvent)
    }
    
    /**
     * Factory method for creating a region event.
     *
     * - Parameter regionID: The ID of the region.
     * - Parameter source: The source of the event.
     * - Parameter boundaryEvent: The type of boundary crossing event.
     * - Parameter circularRegion: The circular region info.
     * - Parameter proximityRegion: The proximity region info.
     *
     * - Returns: Region event object or `nil` if error occurs.
     */
    @objc(
        regionEventWithRegionID:
            source:
            boundaryEvent:
            circularRegion:
            proximityRegion:
    )
    public class func regionEvent(
        regionID: String,
        source: String,
        boundaryEvent: OUABoundaryEvent,
        circularRegion: CircularRegion?,
        proximityRegion: ProximityRegion?
    ) -> OUARegionEvent {
        let regionEvent = RegionEvent(regionID: regionID, source: source, boundaryEvent: boundaryEvent.event, circularRegion: circularRegion, proximityRegion: proximityRegion)
        return OUARegionEvent(event: regionEvent)
    }
}

@objc
public class OUABoundaryEvent: NSObject {
    var event: UABoundaryEvent
    
    public init(boundaryEvent: UABoundaryEvent) {
        event = boundaryEvent
    }
}