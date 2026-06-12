import SwiftUI

/// A custom password input field with an optional visibility toggle.
struct PasswordField: View {
    let placeholder: String
    @Binding var text: String
    var showToggle: Bool = true

    @State private var isSecure: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 14))

            if showToggle {
                Button(action: { isSecure.toggle() }) {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
