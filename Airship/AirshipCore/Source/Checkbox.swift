/* Copyright Airship and Contributors */

import Foundation
import SwiftUI


struct Checkbox: View {
    let info: ThomasViewInfo.Checkbox
    let constraints: ViewConstraints
    @EnvironmentObject var formState: FormState
    @EnvironmentObject var checkboxState: CheckboxState
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    private func createToggle() -> some View {
        let isOn = Binding<Bool>(
            get: {
                self.checkboxState.selectedItems.contains(self.info.properties.reportingValue)
            },
            set: {
                if $0 {
                    self.checkboxState.selectedItems.insert(self.info.properties.reportingValue)
                } else {
                    self.checkboxState.selectedItems.remove(self.info.properties.reportingValue)
                }
            }
        )

        Toggle(isOn: isOn.animation()) {}
            .thomasToggleStyle(
                self.info.properties.style,
                colorScheme: colorScheme,
                constraints: self.constraints,
                disabled: !formState.isFormInputEnabled
            )
    }

    var body: some View {
        let enabled =
        self.checkboxState.selectedItems.contains(self.info.properties.reportingValue)
            || self.checkboxState.selectedItems.count
                < self.checkboxState.maxSelection
        createToggle()
            .constraints(constraints)
            .thomasCommon(self.info)
            .accessible(self.info.accessible)
            .addSelectedTrait(self.checkboxState.selectedItems.contains(self.info.properties.reportingValue))
            .formElement()
            .disabled(!enabled)
    }
}
