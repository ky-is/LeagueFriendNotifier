import Foundation

final class LockfileObserver: NSObject, NSFilePresenter {
	let presentedItemOperationQueue = OperationQueue.main
	let presentedItemURL: URL?

	private let lockfileName = "lockfile"

	init(url: URL) {
		self.presentedItemURL = url
		super.init()
		updateLockfile(url.appendingPathComponent(lockfileName))
	}

	func presentedSubitemDidChange(at url: URL) {
		if url.lastPathComponent == lockfileName {
			updateLockfile(url)
		}
	}

	private func updateLockfile(_ url: URL) {
		let hasLockfile = FileManager.default.fileExists(atPath: url.path)
		StatusBarItem.shared.update(connected: hasLockfile)
//		print(url.lastPathComponent, hasLockfile)
		if hasLockfile {
			ClientBridge.shared.readLockfile()
		} else {
			ClientBridge.shared.close()
		}
	}
}
