import Cocoa
import UserNotifications

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		if let leagueURL = BookmarkManager.shared.load(key: .lockfileKey) {
			ClientBridge.shared.observeLockfile(in: leagueURL)
		} else {
			let leagueDirectory = NSWorkspace.shared.runningApplications
				.lazy
				.compactMap { app in app.bundleURL }
				.first { $0.lastPathComponent == "LeagueClient.app" }
			guard let lockfileDirectory = leagueDirectory?.deletingLastPathComponent() else {
				let alert = NSAlert()
				alert.messageText = "League of Legends not detected"
				alert.informativeText = "The client needs to be running during this one-time setup process. Please relaunch and try again."
				alert.runModal()
				NSApp.terminate(self)
				return
			}
			let openPanel = NSOpenPanel()
			openPanel.message = "Grant League Friend Notifier access to the client API by pressing the Open button on the preselected directory."
			openPanel.canCreateDirectories = false
			openPanel.canChooseDirectories = true
			openPanel.canChooseFiles = false
			openPanel.allowsMultipleSelection = false
			openPanel.directoryURL = lockfileDirectory
//			openPanel.allowedFileTypes = [String(kUTTypePlainText)]
			openPanel.begin { response in
				if let url = openPanel.url {
					ClientBridge.shared.observeLockfile(in: url)
					BookmarkManager.shared.save(key: .lockfileKey, url: url)
				}
			}
		}
		requestNotificationAuthorization()
		StatusBarItem.shared.update(friends: nil)
//		NSWorkspace.shared.launchApplication("League of Legends")
	}

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
