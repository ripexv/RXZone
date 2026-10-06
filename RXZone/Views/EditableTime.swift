//
//  EditableTime.swift
//  RXZone
//

import SwiftUI

/// A clock reading that turns into a field when clicked, so a time can be typed
/// straight into it. Shared by the rows and the header, so both behave alike.
struct EditableTime: View {
    let text: String
    let font: Font
    /// Spoken and shown in the tooltip, e.g. "London".
    let placeName: String
    /// Width of the field while editing, sized to the font.
    var fieldWidth: CGFloat = 80
    /// Called with minutes from midnight. `nil` makes the time read-only.
    let onSetTime: ((Int) -> Void)?

    @Binding var isEditing: Bool

    @State private var draft = ""
    @State private var isInvalid = false
    @State private var isHovering = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        if isEditing {
            TextField(text: $draft, prompt: Text(verbatim: text)) {
                Text("Time in \(placeName)", comment: "Accessibility label for the time field")
            }
            .textFieldStyle(.plain)
            .font(font)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(width: fieldWidth)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isInvalid ? Color.red : Color.accentColor, lineWidth: 1)
            )
            .focused($isFieldFocused)
            .onSubmit(commit)
            .onExitCommand { isEditing = false }
            .onChange(of: draft) { _, _ in isInvalid = false }
            // Clicking elsewhere abandons the edit rather than leaving a field open.
            .onChange(of: isFieldFocused) { _, focused in if !focused { isEditing = false } }
            .onAppear {
                draft = ""
                isInvalid = false
                isFieldFocused = true
            }
        } else {
            Button {
                if onSetTime != nil { isEditing = true }
            } label: {
                Text(text)
                    .font(font)
                    .monospacedDigit()
                    .padding(.horizontal, 3)
                    .background(
                        isHovering && onSetTime != nil ? Color.primary.opacity(0.08) : .clear,
                        in: .rect(cornerRadius: 5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(onSetTime == nil)
            .onHover { isHovering = $0 }
            .help(Text("Type a time in \(placeName) to see it everywhere",
                       comment: "Tooltip on a row's time"))
        }
    }

    private func commit() {
        guard let minutes = TimeInput.minutes(from: draft) else {
            // Stay open and say so, rather than silently doing nothing.
            isInvalid = true
            return
        }
        onSetTime?(minutes)
        isEditing = false
    }
}
