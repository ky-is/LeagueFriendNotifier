import Foundation

extension UserDefaults {
	enum Key: String {
		case lockfileKey
	}
}

struct BookmarkManager {
	static let shared = BookmarkManager()

	func save(key: UserDefaults.Key, url: URL) {
		let data: Data
		do {
			data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
		} catch {
			print(#function, url, error.localizedDescription)
			return
		}
		UserDefaults.standard.set(data, forKey: key.rawValue)
	}

	func load(key: UserDefaults.Key) -> URL? {
		guard let bookmarkData = UserDefaults.standard.object(forKey: key.rawValue) as? Data else {
			return nil
		}
		do {
			var isStale = false
			let url = try URL(resolvingBookmarkData: bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
			guard !isStale, url.startAccessingSecurityScopedResource() else {
				print(#function, isStale, url)
				return nil
			}
			return url
		} catch {
			print(#function, error.localizedDescription)
			return nil
		}
	}
}
