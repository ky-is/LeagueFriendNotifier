import Cocoa

final class StatusBarItem {
	static let shared = StatusBarItem()

	private let item: NSStatusItem

	init() {
		item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		let menu = NSMenu(title: "Friends")
		menu.items = [NSMenuItem(title: "Test", action: nil, keyEquivalent: "")]
		item.menu = menu
		if let button = item.button {
			let image = NSImage(named: NSImage.touchBarTextLeftAlignTemplateName)
			image?.isTemplate = true
			button.image = image
		}
	}
}
