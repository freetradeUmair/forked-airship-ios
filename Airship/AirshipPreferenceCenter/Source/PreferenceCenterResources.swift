/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Resources for AirshipPreferenceCenter.
 */
public class PreferenceCenterResources : NSObject {

    /**
     * Resource bundle for AirshipPreferenceCenter.
     * - Returns: The preference center bundle.
     */
    @objc
    public static func bundle() -> Bundle? {
        let mainBundle = Bundle.main
        let sourceBundle = Bundle(for: Self.self)

        let path = mainBundle.path(forResource: "Airship_AirshipPreferenceCenter", ofType: "bundle") ??
                   mainBundle.path(forResource: "AirshipPreferenceCenterResources", ofType: "bundle") ??
                   sourceBundle.path(forResource: "AirshipPreferenceCenterResources", ofType: "bundle") ?? ""

        return Bundle(path: path) ?? sourceBundle
    }

    public static func localizedString(key: String) -> String? {
        return key.localizedString(withTable:"UrbanAirship", moduleBundle:bundle())
    }
}