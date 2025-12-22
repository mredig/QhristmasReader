@preconcurrency import MultipeerConnectivity
@preconcurrency import SwiftPizzaSnips

@Observable
class LocalNetworkEngineServer: LocalNetworkEngine, @unchecked Sendable {
	private nonisolated let advertiser: MCNearbyServiceAdvertiser

	let coreDataStack: CoreDataStack

	private(set) var isRunning = false

	@MainActor
	private init(
		session: MCSession,
		advertiser: MCNearbyServiceAdvertiser,
		coreDataStack: CoreDataStack
	) async {
		self.advertiser = advertiser
		self.coreDataStack = coreDataStack
		super.init(session: session)
		advertiser.delegate = self
	}

	convenience init(username: String, coreDataStack: CoreDataStack) async {
		let peerID = MCPeerID(displayName: username)
		let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceTypeIdentifier)

		await self.init(session: session, advertiser: advertiser, coreDataStack: coreDataStack)
	}

	func start() {
		advertiser.startAdvertisingPeer()
		isRunning = true
	}

	func stop() {
		advertiser.stopAdvertisingPeer()
		isRunning = false
	}

	override func didConnect(to peer: MCPeerID) {
		print("\(peer) is connected")
	}

	override func didStartConnecting(to peer: MCPeerID) {
		print("\(peer) is connecting")
	}

	override func didDisconnect(from peer: MCPeerID) {
		print("\(peer) disconnected")
	}
}

extension LocalNetworkEngineServer: MCNearbyServiceAdvertiserDelegate {
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
		print("\(#function): - \(error)")
	}

	nonisolated
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		print("\(#function): \(peerID) - \(context as Any)")

		invitationHandler(true, session)
	}
}

extension LocalNetworkEngineServer {
	override func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		Task {
			try await handleRawRequest(data, peer: peerID)
		}
	}
}

// these methods should actually go into something like a router, but it's late
extension LocalNetworkEngineServer {
	struct RequestMeta: Codable, Sendable {
		let server: MCPeerID.SendableDTO
		let client: MCPeerID.SendableDTO
		let requestID: UUID

		let invocation: Invocation
		let headers: [String: String]
	}

	struct RequestPayload<T: Codable & Sendable>: Codable, Sendable {
		let body: T
	}

	func handleRawRequest(_ data: Data, peer: MCPeerID) async throws {
		let meta = try decoder.decode(RequestMeta.self, from: data)
		print("Processing incoming request from \(peer) for '\(meta.invocation.rawValue)'")
		let clientID = try MCPeerID.fromSendableData(meta.client)

		do {
			let response: Response
			switch meta.invocation.components.first {
			case Invocation.getHostIP.rawValue:
				let ips = getLocalIPAddress()
				response = try Response(fromRequest: meta, body: ips)
			default:
				print("Unknown invocation requested: '\(meta.invocation.rawValue)'")
				return
			}

			let responseData = try encoder.encode(response)
			try session.send(responseData, toPeers: [clientID], with: .reliable)
			print("Replied to request from \(peer) for '\(meta.invocation.rawValue)'")
		} catch {
			let errorResponse = ErrorResponse(message: "Error processing request: \(error.localizedDescription)")
			let errorData = try encoder.encode(errorResponse)
			try session.send(errorData, toPeers: [clientID], with: .reliable)
		}
	}

	private func getLocalIPAddress() -> [String] {
		var ifaddr: UnsafeMutablePointer<ifaddrs>?

		guard getifaddrs(&ifaddr) == 0 else { return [] }
		defer { freeifaddrs(ifaddr) }

		var interfacePTR = ifaddr?.pointee

		var interfaces: [IFAddrInfo] = []

		while let interface = interfacePTR {
			defer { interfacePTR = interface.ifa_next?.pointee }
			guard let new = IFAddrInfo(from: interface) else {
				print("Encountered failure")
				continue
			}
			interfaces.append(new)
		}

		let ips = interfaces.filter {
			$0.family != nil &&
			$0.isUp &&
			$0.isRunning &&
			$0.isLoopback == false &&
			$0.name.hasPrefix("en")
		}

		return ips
			.sorted(by: {
				switch ($0.family, $1.family) {
				case (.ip4, .ip6), (.ip4, nil):
					true
				case (.ip4, .ip4), (.ip6, .ip6):
					$0.name < $1.name
				default:
					false
				}
			})
			.map(\.rawAddress)
	}

	enum ServerError: Error {
		case invalidInvocationComponent
		case noMatchingGift
	}

	struct ErrorResponse: Codable, Sendable, Hashable {
		let message: String
	}
}

extension LocalNetworkEngine.Invocation {
	static let getHostIP: Self = "getHostIP"
}
