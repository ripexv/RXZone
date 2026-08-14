//
//  TimeTravelControl.swift
//  RXZone
//

import SwiftUI

/// Slider spanning −24h … now … +24h.
///
/// Moving it only changes the date the views render; the system clock is never
/// touched. When the offset is non-zero the control tints itself so the shown
/// times are never mistaken for the present.
struct TimeTravelControl: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: model.isTimeTravelling ? "clock.arrow.2.circlepath" : "clock")
                    .imageScale(.small)
                    .foregroundStyle(model.isTimeTravelling ? Color.accentColor : .secondary)

                Text("Time Travel", comment: "Section title for the time offset slider")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Text(DateFormatting.travelLabel(minutes: Int(model.travelMinutes)))
                    .font(.caption)
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .foregroundStyle(model.isTimeTravelling ? Color.accentColor : .secondary)

                if model.isTimeTravelling {
                    Button {
                        model.resetTravel()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .imageScale(.small)
                    }
                    .buttonStyle(.borderless)
                    .help(Text("Return to the current time", comment: "Reset button tooltip"))
                    .accessibilityLabel(Text("Reset to now", comment: "Reset button"))
                }
            }

            HStack(spacing: 6) {
                stepButton(hours: -1, symbol: "minus")

                Slider(
                    value: $model.travelMinutes,
                    in: AppModel.travelRange,
                    step: model.preferences.travelStep.minutes
                ) {
                    Text("Time offset", comment: "Slider accessibility label")
                }
                .controlSize(.small)
                .tint(model.isTimeTravelling ? Color.accentColor : Color.secondary)
                .accessibilityValue(Text(DateFormatting.travelLabel(minutes: Int(model.travelMinutes))))

                stepButton(hours: 1, symbol: "plus")
            }
        }
    }

    private func stepButton(hours: Int, symbol: String) -> some View {
        Button {
            model.nudgeTravel(hours: hours)
        } label: {
            Image(systemName: symbol)
                .imageScale(.small)
                .frame(width: 14, height: 14)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(hours < 0
            ? Text("Go back one hour", comment: "Time travel step button")
            : Text("Go forward one hour", comment: "Time travel step button"))
    }
}
