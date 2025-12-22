@preconcurrency import MultipeerConnectivity
@preconcurrency import SwiftPizzaSnips

class DiscoveryClient: DiscoveryEngine, @unchecked Sendable {

	protocol Delegate: AnyObject {
		func localNetworkEngineClient(_ localNetworkEngineClient: DiscoveryClient, finishedWithEvent: Event)
	}

	private let browserVC: MCBrowserViewController

	private var pendingRequests: [UUID: CheckedContinuation<(Data, [String: String]), Error>] = [:]

	private var server: MCPeerID?

	weak var clientDelegate: Delegate?

	@MainActor
	override init(session: MCSession) {
		let browser = MCBrowserViewController(serviceType: Self.serviceTypeIdentifier, session: session)
		self.browserVC = browser
		browser.maximumNumberOfPeers = 1

		super.init(session: session)
		browser.delegate = self
	}

	@MainActor
	convenience init(username: String) {
		let peerID = MCPeerID(displayName: username)
		let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)

		self.init(session: session)
	}

	@MainActor
	func showBrowser(on parentVC: UIViewController) {
		browserVC.title = "Select Event Host"
		browserVC.navigationItem.largeTitleDisplayMode = .always
		parentVC.present(browserVC, animated: true)
	}

	@MainActor
	func dismissBrowser() {
		browserVC.dismiss(animated: true)
	}

	override func didConnect(to peer: MCPeerID) {
		guard server == nil else { return }
		server = peer
		clientDelegate?.localNetworkEngineClient(self, finishedWithEvent: .connectionMade)
	}

	func disconnect() {
		session.disconnect()
	}

	enum Event {
		case userTapCancel
		case userTapDone
		case connectionMade
	}
}

extension DiscoveryClient: MCBrowserViewControllerDelegate {
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
			clientDelegate?.localNetworkEngineClient(self, finishedWithEvent: .userTapDone)
		}
	}
	
	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
			clientDelegate?.localNetworkEngineClient(self, finishedWithEvent: .userTapCancel)
		}
	}
}

extension DiscoveryClient {
	override nonisolated func session(
		_ session: MCSession,
		didReceive data: Data,
		fromPeer peerID: MCPeerID
	) {
		do {
			let response = try decoder.decode(Response.self, from: data)

			guard
				let continuation = pendingRequests[response.requestID]
			else { throw LocalNetworkError.unexpectedResponseID(response.requestID) }

			continuation.resume(returning: (response.body, response.headers))
		} catch {
			print("Error: Received unexpected data from \(peerID): \(error)")
		}
	}

	func sendRequest<Req: Codable, Res: Codable>(_ request: Request<Req>) async throws -> (response: Res, responseHeaders: [String: String]) {
		let clientRequest = try {
			var req = request
			req.client = try session.myPeerID.getSendableData()
			return req
		}()
		async let sendData = encoder.encode(clientRequest)

		async let peerID = MCPeerID.fromSendableData(clientRequest.server)
		print("Sending request for '\(clientRequest.invocation.rawValue)'")
		try await session.send(sendData, toPeers: [peerID], with: .reliable)

		let (responseData, responseHeaders) = try await withThrowingTaskGroup(of: (Data, [String: String]).self) { group in
			defer { self.pendingRequests[clientRequest.requestID] = nil }
			group.addTask {
				return try await withCheckedThrowingContinuation { continuation in
					self.pendingRequests[clientRequest.requestID] = continuation
				}
			}

			group.addTask {
				try await Task.sleep(for: .seconds(clientRequest.timeout))
				let error = LocalNetworkError.timeout(requestID: clientRequest.requestID)
				self.pendingRequests[clientRequest.requestID]?.resume(throwing: error)
				print("Timeout reached for \(clientRequest.invocation.rawValue)")
				throw error
			}

			guard let result = try await group.next() else {
				throw LocalNetworkError.unknown
			}
			print("Got response for '\(clientRequest.invocation.rawValue)'")

			group.cancelAll()
			return result
		}

		async let response = decoder.decode(Res.self, from: responseData)

		return try await (response, responseHeaders)
	}

	enum LocalNetworkError: Error {
		case timeout(requestID: UUID)
		case unexpectedResponseID(UUID)
		case unknown
	}
}

extension DiscoveryClient {
	func sendHostAddressRequest() async throws -> URL {
		guard let server else { throw ClientError.notConnected }

		let request = try Request(server: server.getSendableData(), invocation: .getHostIP)
		let ipStrings: [String] = try await sendRequest(request).response
		let ipString = try ipStrings.first.unwrap()
		let ip = try IPAddress(rawValue: ipString).unwrap(orThrow: ClientError.decodeError(message: "Invalid IP: \(ipString)"))

		let host: String
		switch ip {
		case .ip4(let address):
			host = address.rawValue
		case .ip6(let address):
			host = address.rawValue
		}

		let url = try URL(string: "http://\(host):8080").unwrap(orThrow: ClientError.decodeError(message: "Invalid url"))
		return url
	}

	enum ClientError: Error {
		case notConnected
		case decodeError(message: String?)
	}
}
