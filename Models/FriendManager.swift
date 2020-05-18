import Cocoa
import UserNotifications

struct FriendManager {
	static var friends: [Friend] = []

	static func update(data: [[String: Any]]) {
		for entry in data {
			guard let id = entry["summonerId"] as? Int else {
				continue
			}
			if let oldFriend = getFriend(by: id) {
				oldFriend.update(data: entry)
			} else {
				friends.append(Friend(data: entry))
			}
		}
		friends.sort()
		DispatchQueue.main.async {
			StatusBarItem.shared.update(friends: friends)
		}
	}

	static func getFriend(by id: Int) -> Friend? {
		return friends.first { $0.id == id }
	}
}

final class Friend: Comparable {
	static func == (lhs: Friend, rhs: Friend) -> Bool {
		lhs.id == rhs.id
	}

	static func < (lhs: Friend, rhs: Friend) -> Bool {
		lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
	}

	let id: Int
	var name: String
	var product: String
	var status: String

	static private let offlineStatuses = [ "offline", "mobile" ]
	static private let unavailableStatuses = [ "dnd", "away" ]

	static private func key(_ id: Int) -> String {
		"N#\(id)"
	}

	var enableNotifications: Bool {
		didSet {
			UserDefaults.standard.set(enableNotifications, forKey: Friend.key(id))
			didNotify = false
		}
	}
	var enabledState: NSControl.StateValue {
		get {
			enableNotifications ? .on : .off
		}
	}
	private var didNotify = false

	init(data: [String: Any]) {
		let id = data["summonerId"] as! Int
		self.id = id
		self.name = data["name"] as! String
		self.product = data["product"] as! String
		self.status = data["availability"] as! String
		self.enableNotifications = UserDefaults.standard.bool(forKey: Friend.key(id))
	}

	var isOffline: Bool {
		Friend.offlineStatuses.contains(status)
	}
	var isBusy: Bool {
		Friend.unavailableStatuses.contains(status)
	}

	func notifyIfNeeded() {
		guard !ClientBridge.shared.inGame, enableNotifications, !didNotify else {
			return
		}
		guard product == "league_of_legends", !isOffline, !isBusy else {
			didNotify = false
			return
		}
		let notification = UNMutableNotificationContent()
		notification.title = "\(name) is online!"
		notification.body = "Click to view in League of Legends."
		notification.sound = nil
		notification.categoryIdentifier = "online"
		notification.threadIdentifier = "online"
		let request = UNNotificationRequest(identifier: id.description, content: notification, trigger: nil)
		UNUserNotificationCenter.current().add(request)
		didNotify = true
	}

	func update(data: [String: Any]) {
		self.product = data["product"] as! String
		self.status = data["availability"] as! String
		notifyIfNeeded()
	}
}
