import SwiftUI

@main
struct MultiTerminalApp: App {
    init() {
        // SPM executables have no bundle identifier; disable window tabbing
        // to avoid "Cannot index window tabs" console warnings.
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .navigationTitle("Multi-Term")
                .onAppear {
                    // SPM executables launch as background/accessory processes.
                    // Without this, macOS routes key events to the previously
                    // active app (Xcode) instead of our window.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
