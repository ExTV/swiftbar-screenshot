import SwiftUI
import ServiceManagement
@main
struct ScreenShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            print("Failed to register for launch at login: \(error)")
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
