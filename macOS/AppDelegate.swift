import Cocoa
import UserNotifications

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		requestLockfile()
		requestNotificationAuthorization()
		StatusBarItem.shared.update(friends: nil)
	}

	private func retryRequest(title: String, body: String) {
		let alert = NSAlert()
		alert.messageText = title
		alert.informativeText = body
		alert.runModal()
		requestLockfile()
	}

	private func requestLockfile() {
		if let leagueURL = BookmarkManager.shared.load(key: .lockfileKey) {
			ClientBridge.shared.observeLockfile(in: leagueURL)
		} else {
			let leagueDirectory = NSWorkspace.shared.runningApplications
				.lazy
				.compactMap { $0.bundleURL }
				.first { $0.lastPathComponent == "LeagueClient.app" }
			guard let lockfileDirectory = leagueDirectory?.deletingLastPathComponent() else {
				return retryRequest(title: "League of Legends not detected", body: "The client needs to be running during this one-time setup process. Please relaunch and try again.")
			}
			let openPanel = NSOpenPanel()
			openPanel.message = "Grant access to the client API by opening the preselected directory."
			openPanel.canCreateDirectories = false
			openPanel.canChooseDirectories = true
			openPanel.canChooseFiles = false
			openPanel.allowsMultipleSelection = false
			openPanel.directoryURL = lockfileDirectory
			openPanel.begin { response in
				guard response == .OK else {
					return self.retryRequest(title: "Please approve access to the League Client API", body: "To connect to the client, we first need your permission to access to its data directory.")
				}
				guard let url = openPanel.url, FileManager.default.fileExists(atPath: url.appendingPathComponent("lockfile").path) else {
					return self.retryRequest(title: "Invalid directory selected", body: "Please choose the pre-selected directory when prompted.")
				}
				ClientBridge.shared.observeLockfile(in: url)
				BookmarkManager.shared.save(key: .lockfileKey, url: url)
			}
		}
	}

	static func openLeagueOfLegends() {
		let clientBundleID = "com.riotgames.LeagueofLegends.LeagueClient"
		let uxBundleID = clientBundleID + "Ux"
		if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == uxBundleID }) {
			app.activate(options: [.activateIgnoringOtherApps])
		} else {
			NSWorkspace.shared.launchApplication(withBundleIdentifier: clientBundleID, options: [], additionalEventParamDescriptor: nil, launchIdentifier: nil)
		}
	}
}

extension AppDelegate: UNUserNotificationCenterDelegate {
	private func requestNotificationAuthorization() {
		UNUserNotificationCenter.current().delegate = self
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { enabled, error in
			if let error = error {
				print(#function, enabled, error.localizedDescription)
			}
		}
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
		AppDelegate.openLeagueOfLegends()
		completionHandler()
	}

	func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
		completionHandler(.alert)
	}
}
