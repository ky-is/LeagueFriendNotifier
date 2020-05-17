import Cocoa

final class StatusBarItem {
	static let shared = StatusBarItem()

	private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
	private let menu = NSMenu(title: "Friends")

	private var friendItems: [NSMenuItem]?
	private var isConnected: Bool?

	init() {
		item.menu = menu
		if let button = item.button {
			let image = NSImage(named: NSImage.touchBarTextLeftAlignTemplateName)
			image?.isTemplate = true
			button.image = image
		}
	}

	func update(connected: Bool?) {
		isConnected = connected
		updateMenu()
	}

	func update(friends: [Friend]?) {
		friendItems = friends?.map { friend in
			let icon = friend.isOffline ? "⚫️" : friend.isBusy ? "🔴" : "🟢"
			let item = NSMenuItem(title: "\(icon) \(friend.name)", action: #selector(toggleNotifications), keyEquivalent: "")
			item.tag = friend.id
			item.target = self
			item.state = friend.enabledState
			return item
		}
		updateMenu()
	}

	private func updateMenu() {
		var menuItems: [NSMenuItem] = []
		if let isConnected = isConnected {
			let launch = NSMenuItem(title: (isConnected ? "View" : "Open") + " League of Legends", action: #selector(onOpenLeague), keyEquivalent: "")
			launch.target = self
			menuItems.append(launch)
			menuItems.append(NSMenuItem.separator())
		}
		if let friendItems = friendItems {
			let title = NSMenuItem(title: !friendItems.isEmpty ? "Online notifications for:" : "Empty friends list", action: nil, keyEquivalent: "")
			menuItems.append(title)
			menuItems += friendItems
			menuItems.append(NSMenuItem.separator())
		}
		let quit = NSMenuItem(title: "Quit League Friend Notifier", action: #selector(onQuit), keyEquivalent: "")
		quit.target = self
		menuItems.append(quit)
		menu.items = menuItems
	}

	@objc private func toggleNotifications(sender: NSMenuItem) {
		guard let friend = FriendManager.getFriend(by: sender.tag) else {
			return
		}
		friend.enableNotifications.toggle()
		sender.state = friend.enabledState
	}

	@objc private func onQuit(sender: NSMenuItem) {
		NSApp.terminate(self)
	}

	@objc private func onOpenLeague(sender: NSMenuItem) {
		AppDelegate.openLeagueOfLegends()
	}
}
