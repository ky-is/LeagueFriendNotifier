import Foundation

enum HTTPMethod: String {
	case get, post
}

final class ClientBridge: NSObject {
	static let shared = ClientBridge()

	private var session: URLSession!
	private var websocket: URLSessionWebSocketTask?
	private var baseURL: URL!
	private var authorization: String!

	override init() {
		super.init()
		session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
	}

	func readLockfile(_ url: URL) {
		do {
			let contents = try String(contentsOf: url)
			let split = contents.split(separator: ":")
//			let name = String(split[0])
//			let pid = Int(split[1]) ?? 0
			guard let port = Int(split[2]) else {
				return print("Invalid port", split[2], contents)
			}
			let token = String(split[3])
			authorization = "riot:\(token)".data(using: .utf8)!.base64EncodedString()
			let httpProtocol = String(split[4])
			baseURL = URL(string: "\(httpProtocol)://127.0.0.1:\(port)")

			let wsURL = URL(string: "wss://127.0.0.1:\(port)")!
			let request = createRequest(for: wsURL)
			session.webSocketTask(with: request).resume()
		} catch {
			print("Unable to read lockfile", error.localizedDescription)
		}
	}

	private func handleMessage(result: Result<URLSessionWebSocketTask.Message, Error>) {
		websocket?.receive(completionHandler: handleMessage)
		switch result {
		case .success(let message):
			switch message {
			case .data(let data):
				print("WS Data?", data)
			case .string(let string):
				guard !string.isEmpty else {
					return
				}
				guard let data = try? JSONSerialization.jsonObject(with: string.data(using: .utf8)!, options: []) as? [Any] else {
					return print("Unable to decode", string)
				}
				guard let contents = data[2] as? [String: Any], let uri = contents["uri"] as? String else {
					return print("Invalid contents", data[2])
				}
				switch uri {
				default:
//					print(uri)
					break
				}
			@unknown default:
				print("Unknown message type")
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
		session.webSocketTask(with: request).resume()
		let task = session.dataTask(with: request) { data, response, error in
			if let error = error {
				return print(error.localizedDescription)
			}
			guard let data = data else {
				return
			}
			guard let callback = callback else {
				return
			}
			do {
				let json = try JSONSerialization.jsonObject(with: data, options: [])
				callback(json)
			} catch {
				print(error.localizedDescription)
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
}

extension ClientBridge: URLSessionWebSocketDelegate {
	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
		websocket = webSocketTask
		webSocketTask.receive(completionHandler: handleMessage)
		subscribe()
	}

	private func subscribe() {
		let message = try! JSONSerialization.data(withJSONObject: [5, "OnJsonApiEvent"], options: [])
		websocket?.send(.data(message)) { error in
			if let error = error {
				print("Unable to subscribe for callbacks", error.localizedDescription)
			}
		}
	}

	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		print("CLOSED")
		websocket = nil
		//TODO wait for readLockfile
	}
}
