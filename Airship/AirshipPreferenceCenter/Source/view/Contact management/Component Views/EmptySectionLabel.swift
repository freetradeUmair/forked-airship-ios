/* Copyright Airship and Contributors */

import SwiftUI

struct EmptySectionLabel: View {
    static let padding = EdgeInsets(top: 0, leading: 25, bottom: 5, trailing: 0)

    // The empty message
    var label: String?

    /// The preference center theme
    var theme: PreferenceCenterTheme.ChannelSubscription?

    var action: (()->())?

    public var body: some View {
        if let label = label {
            VStack(alignment: .leading) {
                HStack(spacing:12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.gray.opacity(0.8))
                    /// Message
                    Text(label)
                        .textAppearance(
                            theme?.emptyTextAppearance,
                            base: DefaultContactManagementSectionStyle.subtitleAppearance
                        )
                    Spacer()
                }
            }
            .transition(.opacity)
            .padding(5)
        }
    }
}
