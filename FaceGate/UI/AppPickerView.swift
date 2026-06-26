import SwiftUI
import AppKit

/// A native macOS component for displaying and managing a list of apps.
struct AppPickerView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @State private var searchText = ""
    @State private var selectedAppIDs = Set<String>()
    
    /// Called when the user wants to configure the app (e.g., set timer)
    var onClickApp: ((LockedApp) -> Void)?
    
    private var filteredApps: [LockedApp] {
        if searchText.isEmpty {
            return lockedAppsManager.lockedApps
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        return lockedAppsManager.lockedApps
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Search Bar and instructions
            HStack(alignment: .bottom) {
                Text("Select the applications you want to protect.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                NativeSearchField(text: $searchText, placeholder: "Search…")
                    .frame(width: 180, height: 22)
            }
            .padding(.bottom, 4)
            
            // Container with list and + / - buttons at the bottom
            VStack(spacing: 0) {
                List(selection: $selectedAppIDs) {
                    if filteredApps.isEmpty && searchText.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)
                            Image(systemName: "lock.open")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No Apps Locked")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Protect your apps by adding them to the lock list.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if filteredApps.isEmpty {
                        Text("No apps match your search.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredApps, id: \.bundleIdentifier) { app in
                            HStack(spacing: 12) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: "app.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.secondary)
                                }

                                Text(app.displayName)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                // Explicit timer button so double-click isn't needed, fixing selection
                                Button(action: { onClickApp?(app) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 11, weight: app.customSessionTimeout != nil ? .bold : .regular))
                                        if app.customSessionTimeout != nil {
                                            Text("Custom")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                    }
                                    // Use primary/secondary so it automatically handles selection colors nicely
                                    .foregroundColor(app.customSessionTimeout != nil ? .primary : .secondary)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                            }
                            .padding(.vertical, 4)
                            .tag(app.bundleIdentifier)
                            .contextMenu {
                                Button("Configure Timer") {
                                    onClickApp?(app)
                                }
                                Button("Remove App") {
                                    lockedAppsManager.unlockApp(app.bundleIdentifier)
                                    selectedAppIDs.remove(app.bundleIdentifier)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Plus/Minus Bar
                HStack(spacing: 0) {
                    Button(action: addApps) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .frame(height: 14)
                    
                    Button(action: removeSelectedApps) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 28, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAppIDs.isEmpty)
                    
                    Spacer()
                }
                .frame(height: 28)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }
    
    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let discovered = InstalledAppsScanner.shared.createDiscoveredApp(from: url) {
                    let lockedApp = InstalledAppsScanner.shared.toLockedApp(discovered, isLocked: true)
                    lockedAppsManager.lockApp(lockedApp)
                }
            }
        }
    }
    
    private func removeSelectedApps() {
        for id in selectedAppIDs {
            lockedAppsManager.unlockApp(id)
        }
        selectedAppIDs.removeAll()
    }
}
