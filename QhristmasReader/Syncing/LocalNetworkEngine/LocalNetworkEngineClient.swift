@preconcurrency import MultipeerConnectivity

class LocalNetworkEngineClient: LocalNetworkEngine, @unchecked Sendable {

	let browserVC: MCBrowserViewController

	private var pendingRequests: [UUID: CheckedContinuation<(Data, [String: String]), Error>] = [:]

	private var server: MCPeerID?

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
		parentVC.present(browserVC, animated: true)
	}

	override func didConnect(to peer: MCPeerID) {
		guard server == nil else { return }
		server = peer
	}
}

extension LocalNetworkEngineClient: MCBrowserViewControllerDelegate {
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
		}
	}
	
	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
		}
	}
}

extension LocalNetworkEngineClient {
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

extension LocalNetworkEngineClient {
//	func sendPing() async throws {
//		guard let server else { throw ClientError.notConnected }
//		let request = try Request(
//			server: server.getSendableData(),
//			invocation: .ping)
//		let _: Void = try await sendRequest(request).response
//	}

	func sendRecipientChangelistRequest() async throws -> [UUID: ListItemInfo] {
		guard let server else { throw ClientError.notConnected }
		let request = try Request(
			server: server.getSendableData(),
			invocation: .listRecipientIDs)
		return try await sendRequest(request).response
	}

	func sendRecipientListRequest() async throws -> [Recipient.DTO] {
		guard let server else { throw ClientError.notConnected }
		let request = try Request(
			server: server.getSendableData(),
			invocation: .listRecipients)
		return try await sendRequest(request).response
	}

	func sendRetrieveRecipientRequest(_ recipientID: UUID) async throws -> Recipient.DTO {
		guard let server else { throw ClientError.notConnected }
		let request = try Request(server: server.getSendableData(), invocation: .getRecipient(id: recipientID))

		return try await sendRequest(request).response
	}

	func sendGiftListRequest() async throws -> [UUID: ListItemInfo] {
		guard let server else { throw ClientError.notConnected }
		let request = try Request(
			server: server.getSendableData(),
			invocation: .listGiftIDs)
		return try await sendRequest(request).response
	}

	func sendRetrieveGiftRequest(_ giftID: UUID) async throws -> Gift.DTO {
		guard let server else { throw ClientError.notConnected }
		let request = try Request(server: server.getSendableData(), invocation: .getGift(id: giftID))

		return try await sendRequest(request).response
	}

	enum ClientError: Error {
		case notConnected
	}
}
