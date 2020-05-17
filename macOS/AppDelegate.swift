import Cocoa

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	private var statusItem: StatusBarItem!

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		if let leagueURL = BookmarkManager.shared.load(key: .lockfileKey) {
			ClientBridge.shared.readLockfile(leagueURL)
		} else {
			let lockfileURL = NSWorkspace.shared.runningApplications
				.lazy
				.compactMap { app in app.bundleURL }
				.first { $0.lastPathComponent == "LeagueClient.app" }?
				.deletingLastPathComponent()
				.appendingPathComponent("lockfile")
			let openPanel = NSOpenPanel()
			openPanel.message = "Grant League Friend Notifier access to the client by pressing the Open button on the preselected directory."
			openPanel.canCreateDirectories = false
			openPanel.canChooseDirectories = false
			openPanel.canChooseFiles = true
			openPanel.allowsMultipleSelection = false
			openPanel.directoryURL = lockfileURL
			openPanel.allowedFileTypes = [String(kUTTypePlainText)]
			openPanel.begin { response in
				if let url = openPanel.url {
					ClientBridge.shared.readLockfile(url)
					BookmarkManager.shared.save(key: .lockfileKey, url: url)
				}
			}
		}
		statusItem = StatusBarItem()
	}
}
