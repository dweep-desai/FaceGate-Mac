import SwiftUI

/// Compatibility wrapper for `onChange(of:)` that works across macOS 13 (old API)
/// and macOS 14+ (new API) without deprecation warnings.
extension View {
    /// A cross-version `onChange` that silences the deprecation warning on macOS 14+.
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}
``