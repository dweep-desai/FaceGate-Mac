import SwiftUI

struct PasswordStrengthView: View {
    let password: String
    
    // Criteria Checks
    private var hasLength: Bool { password.count >= 6 }
    private var hasUppercase: Bool { password.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil }
    private var hasLowercase: Bool { password.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil }
    private var hasNumber: Bool { password.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil }
    private var hasSpecial: Bool { 
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;':\",./<>?\\")
        return password.rangeOfCharacter(from: specialChars) != nil 
    }
    
    private var fulfilledCount: Int {
        [hasLength, hasUppercase, hasLowercase, hasNumber, hasSpecial].filter { $0 }.count
    }
    
    private var strengthLabel: String {
        switch fulfilledCount {
        case 0...2: return "Weak password"
        case 3...4: return "Good password"
        case 5: return "Strong password"
        default: return "Weak password"
        }
    }
    
    private var strengthColor: Color {
        switch fulfilledCount {
        case 0...2: return .red
        case 3...4: return .yellow
        case 5: return .green
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Spacer()
                Text(strengthLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            HStack(spacing: 6) {
                ForEach(0..<5) { index in
                    Capsule()
                        .fill(index < fulfilledCount ? strengthColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.2), value: fulfilledCount)
                }
            }
            
            // Criteria List
            VStack(alignment: .leading, spacing: 8) {
                CriteriaRow(title: "At least 6 characters", isMet: hasLength)
                CriteriaRow(title: "At least 1 uppercase letter", isMet: hasUppercase)
                CriteriaRow(title: "At least 1 lowercase letter", isMet: hasLowercase)
                CriteriaRow(title: "At least 1 number", isMet: hasNumber)
                CriteriaRow(title: "At least 1 special character", isMet: hasSpecial)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct CriteriaRow: View {
    let title: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(isMet ? .green : Color.gray.opacity(0.5))
                .font(.system(size: 14))
                .animation(.easeInOut(duration: 0.2), value: isMet)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isMet ? .green : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isMet)
        }
    }
}
