import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    var isFirstRun: Bool {
        !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
    }
    
    var runInBackground: Bool {
        get { UserDefaults.standard.bool(forKey: "RunInBackground") }
        set { UserDefaults.standard.set(newValue, forKey: "RunInBackground") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isFirstRun {
            showSetupDialog()
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        } else {
            setActivationPolicy()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "camera", accessibilityDescription: nil)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Fullscreen", action: #selector(fullscreen), keyEquivalent: "f"))
        menu.addItem(NSMenuItem(title: "Window", action: #selector(window), keyEquivalent: "w"))
        menu.addItem(NSMenuItem(title: "Crop", action: #selector(crop), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Screenshot Folder", action: #selector(openFolder), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Change Folder…", action: #selector(changeFolder), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func setActivationPolicy() {
        NSApp.setActivationPolicy(runInBackground ? .accessory : .regular)
    }

    @objc func fullscreen() { runCaptureCommand(args: []) }
    @objc func window() { runCaptureCommand(args: ["-w"]) }
    @objc func crop() { runCaptureCommand(args: ["-s"]) }

    func runCaptureCommand(args: [String]) {
        guard let folderURL = getScreenshotFolderURL() else { return }

        if folderURL.startAccessingSecurityScopedResource() {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
                .replacingOccurrences(of: "/", with: ".")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: ":", with: ".")

            let path = folderURL.appendingPathComponent("screenshot-\(timestamp).png")

            let process = Process()
            process.launchPath = "/usr/sbin/screencapture"
            process.arguments = args + [path.path]

            process.terminationHandler = { _ in
                if let image = NSImage(contentsOf: path) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([image])
                }
                folderURL.stopAccessingSecurityScopedResource()
            }

            process.launch()
        }
    }

    @objc func openFolder() {
        guard let folderURL = getScreenshotFolderURL() else { return }
        if folderURL.startAccessingSecurityScopedResource() {
            NSWorkspace.shared.open(folderURL)
            folderURL.stopAccessingSecurityScopedResource()
        }
    }

    @objc func changeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select New Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            saveScreenshotFolderBookmark(url: url)
        }
    }

    func saveScreenshotFolderBookmark(url: URL) {
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "ScreenshotFolderBookmark")
        } catch {
            print("Bookmark save failed: \(error)")
        }
    }

    func getScreenshotFolderURL() -> URL? {
        if let data = UserDefaults.standard.data(forKey: "ScreenshotFolderBookmark") {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale { saveScreenshotFolderBookmark(url: url) }
                return url
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        } else {
            return nil
        }
        return nil
    }

    func showSetupDialog() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Screenshot Tool Setup"
        alert.informativeText = "You can choose to run the app in background (hidden from Dock). You will also need to select a download folder."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")

        let checkbox = NSButton(checkboxWithTitle: "Run in background (hide from Dock)", target: nil, action: nil)
        checkbox.state = .on
        alert.accessoryView = checkbox

        alert.runModal()

        runInBackground = (checkbox.state == .on)
        setActivationPolicy()

        // Prompt for screenshot folder
        let panel = NSOpenPanel()
        panel.title = "Choose Screenshot Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            saveScreenshotFolderBookmark(url: url)
        }
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
