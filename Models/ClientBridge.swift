import Foundation

enum HTTPMethod: String {
	case get, post
}

final class ClientBridge: NSObject {
	static let shared = ClientBridge()

	var inGame = false

	private var observer: LockfileObserver?
	private var lockfileDirectory: URL?
	private var session: URLSession!
	private var baseURL: URL!
	private var authorization: String!

	private var wsURL: URL!
	private var webSocketTask: URLSessionWebSocketTask?
	private var retryWebsocketWork: DispatchWorkItem?

	override init() {
		super.init()
		session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
	}

	func observeLockfile(in url: URL) {
		if let observer = observer {
			NSFileCoordinator.removeFilePresenter(observer)
		}
		lockfileDirectory = url
		observer = LockfileObserver(url: url)
		NSFileCoordinator.addFilePresenter(observer!)
	}

	func readLockfile() {
		guard let url = lockfileDirectory else {
			return
		}
		let contents: String
		do {
			contents = try String(contentsOf: url.appendingPathComponent("lockfile"))
		} catch {
			return print(#function, error.localizedDescription)
		}
		let split = contents.split(separator: ":")
//		let name = String(split[0])
//		let pid = Int(split[1]) ?? 0
		guard let port = Int(split[2]) else {
			return print("Invalid port", contents)
		}
		let token = String(split[3])
		authorization = "riot:\(token)".data(using: .utf8)!.base64EncodedString()
		let httpProtocol = String(split[4])
		baseURL = URL(string: "\(httpProtocol)://127.0.0.1:\(port)")
		wsURL = URL(string: "wss://127.0.0.1:\(port)")!
		createWebSocket()
	}

	func close() {
		print("WS CLOSED")
		retryWebsocketWork?.cancel()
		retryWebsocketWork = nil
		webSocketTask?.cancel(with: .goingAway, reason: nil)
		webSocketTask = nil
	}

	private func updateFriendsList() {
		send("/lol-chat/v1/friends") { response in
			if let response = response as? [[String: Any]] {
				FriendManager.update(data: response)
			}
		}
	}

	private func respondToReadyCheck(_ data: [String: Any]) {
		guard let response = data["playerResponse"] as? String, response != "none" else {
			return
		}
		guard let timer = data["timer"] as? Int, timer < Int.random(in: 7...10) else {
			return
		}
		send("/lol-matchmaking/v1/ready-check/accept", method: .post) { response in
			print(response)
		}
	}

	private func updateAvailability(_ data: [String: Any]) {
		if let availability = data["availability"] as? String {
			inGame = availability == "dnd"
		}
	}

	private func createWebSocket() {
		webSocketTask?.cancel(with: .goingAway, reason: nil)
		let request = createRequest(for: wsURL)
		let task = session.webSocketTask(with: request)
		task.resume()
		webSocketTask = task
	}

	private func handleMessage(result: Result<URLSessionWebSocketTask.Message, Error>) {
		webSocketTask?.receive(completionHandler: handleMessage)
		switch result {
		case .success(let message):
			let rawData: Data
			switch message {
			case .data(let wsData):
				rawData = wsData
			case .string(let string):
				guard !string.isEmpty, let stringData = string.data(using: .utf8) else {
					return
				}
				rawData = stringData
			@unknown default:
				print("Unknown message type")
				return
			}

			guard let json = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [Any] else {
				return print("Unable to decode", rawData)
			}
			guard let contents = json[2] as? [String: Any], let uri = contents["uri"] as? String else {
				return print("Invalid contents", json[2])
			}
			switch uri {
			case "/lol-chat/v1/friend-counts":
				updateFriendsList()
			case "/lol-matchmaking/v1/ready-check":
				if let data = contents["data"] as? [String: Any] {
					respondToReadyCheck(data)
				}
			case "/lol-chat/v1/me":
				if let data = contents["data"] as? [String: Any] {
					updateAvailability(data)
				}
			default:
//				print(uri) //SAMPLE
				return
			}
		case .failure(let error):
			print(error.localizedDescription)
		}
	}

	private func createRequest(for url: URL) -> URLRequest {
		var request = URLRequest(url: url)
		request.addValue("Basic \(authorization!)", forHTTPHeaderField: "Authorization")
		return request
	}

	func send(_ name: String, method: HTTPMethod? = nil, callback: ((Any) -> Void)? = nil) {
		var request = createRequest(for: baseURL.appendingPathComponent(name))
		request.httpMethod = method?.rawValue
		let task = session.dataTask(with: request) { data, response, error in
			if let error = error {
				return print(#function, error.localizedDescription)
			}
			guard let data = data, let callback = callback else {
				return
			}
			do {
				let json = try JSONSerialization.jsonObject(with: data, options: [])
				callback(json)
			} catch {
				print("JSON", error.localizedDescription)
			}
		}
		task.resume()
	}
}

extension ClientBridge: URLSessionDelegate {
	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		let trust = challenge.protectionSpace.serverTrust
		let credential = trust != nil ? URLCredential(trust: trust!) : URLCredential()
		completionHandler(.useCredential, credential)
	}

	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		print("INVALID", error?.localizedDescription ?? "")
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if task is URLSessionWebSocketTask {
			close()
			let work = DispatchWorkItem(block: createWebSocket)
			DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: work)
			retryWebsocketWork = work
		} else {
			print(#function, error?.localizedDescription ?? "")
		}
	}
}

extension ClientBridge: URLSessionWebSocketDelegate {
	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
		print("WS OPEN")
		webSocketTask.receive(completionHandler: handleMessage)
		subscribe()
		updateFriendsList()
	}

	private func subscribe() {
		let message = try! JSONSerialization.data(withJSONObject: [5, "OnJsonApiEvent"], options: [])
		webSocketTask?.send(.data(message)) { error in
			if let error = error {
				print("Unable to subscribe for callbacks", error.localizedDescription)
			}
		}
	}

	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		print("WS CLOSED")
		close()
	}
}
