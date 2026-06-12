import AppKit
import SwiftUI

/// Reusable view to display an application's icon with consistent sizing and styling.
struct AppIconView: View {
    let icon: NSImage?
    let size: CGFloat

    init(icon: NSImage?, size: CGFloat = 40) {
        self.icon = icon
        self.size = size
    }

    /// Initialize from icon data (e.g., from LockedApp).
    init(iconData: Data?, size: CGFloat = 40) {
        if let data = iconData {
            self.icon = NSImage(data: data)
        } else {
            self.icon = nil
        }
        self.size = size
    }

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}
