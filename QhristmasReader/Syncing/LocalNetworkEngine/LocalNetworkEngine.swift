@preconcurrency import MultipeerConnectivity
import SwiftPizzaSnips

class LocalNetworkEngine: NSObject {
	protocol Delegate: AnyObject {
		func localNetworkEngine(_ localNetworkEngine: LocalNetworkEngine, didStartConnectingToNewPeer peer: MCPeerID)
		func localNetworkEngine(_ localNetworkEngine: LocalNetworkEngine, didConnectToNewPeer peer: MCPeerID)
		func localNetworkEngine(_ localNetworkEngine: LocalNetworkEngine, didDisconnectFromPeer peer: MCPeerID)

	}

	static let encoder = JSONEncoder()
	var encoder: JSONEncoder { Self.encoder }
	static let decoder = JSONDecoder()
	var decoder: JSONDecoder { Self.decoder }

	static let serviceTypeIdentifier = "qhristmasreader"

	var selfPeerID: MCPeerID { session.myPeerID }
	nonisolated let session: MCSession
	var connectedPeers: [MCPeerID] { session.connectedPeers }

	weak var delegate: Delegate?

	@MainActor
	init(session: MCSession) {
		self.session = session
		super.init()
		session.delegate = self
	}

	open func didConnect(to peer: MCPeerID) {}

	open func didStartConnecting(to peer: MCPeerID) {}

	open func didDisconnect(from peer: MCPeerID) {}
}

extension LocalNetworkEngine: MCSessionDelegate {
	nonisolated
	func session(
		_ session: MCSession,
		peer peerID: MCPeerID,
		didChange state: MCSessionState
	) {
		switch state {
		case .notConnected:
			didDisconnect(from: peerID)
			delegate?.localNetworkEngine(self, didDisconnectFromPeer: peerID)
		case .connecting:
			didStartConnecting(to: peerID)
			delegate?.localNetworkEngine(self, didStartConnectingToNewPeer: peerID)
		case .connected:
			didConnect(to: peerID)
			delegate?.localNetworkEngine(self, didConnectToNewPeer: peerID)
		@unknown default:
			fatalError("Unknown state: \(state)")
		}
	}

	nonisolated
	func session(
		_ session: MCSession,
		didReceive data: Data,
		fromPeer peerID: MCPeerID
	) { print("\(#function) not implemented") }

	func session(
		_ session: MCSession,
		didReceive stream: InputStream,
		withName streamName: String,
		fromPeer peerID: MCPeerID
	) { print("\(#function) not implemented") }

	func session(
		_ session: MCSession,
		didStartReceivingResourceWithName resourceName: String,
		fromPeer peerID: MCPeerID,
		with progress: Progress
	) { print("\(#function) not implemented") }

	func session(
		_ session: MCSession,
		didFinishReceivingResourceWithName resourceName: String,
		fromPeer peerID: MCPeerID,
		at localURL: URL?,
		withError error: (any Error)?
	) { print("\(#function) not implemented") }
}

extension LocalNetworkEngine {
	static let defaultRequestTimeout: TimeInterval = 30

	struct Request<T: Codable & Sendable>: Codable, Sendable {
		var server: MCPeerID.SendableDTO
		var client: MCPeerID.SendableDTO?
		let requestID: UUID

		var invocation: Invocation
		var headers: [String: String] = [:]

		var timeout: TimeInterval

		var body: T

		init(
			server: MCPeerID.SendableDTO,
			requestID: UUID = UUID(),
			invocation: Invocation,
			timeout: TimeInterval = LocalNetworkEngine.defaultRequestTimeout,
			headers: [String : String] = [:],
			body: T
		) {
			self.server = server
			self.requestID = requestID
			self.invocation = invocation
			self.timeout = timeout
			self.headers = headers
			self.body = body
		}
	}

	struct Invocation: RawRepresentable, Codable, Sendable, Hashable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
		var rawValue: String

		init(rawValue: String) {
			self.rawValue = rawValue
		}

		init(stringLiteral value: String) {
			self.init(rawValue: value)
		}

		var components: [String] {
			rawValue.split(separator: "/").compactMap { $0.removingPercentEncoding }
		}
	}
	struct Empty: Codable, Sendable, Hashable {}
}

extension LocalNetworkEngine.Request where T == Optional<LocalNetworkEngine.Empty> {
	init(
		server: MCPeerID.SendableDTO,
		invocation: LocalNetworkEngine.Invocation,
		timeout: TimeInterval = LocalNetworkEngine.defaultRequestTimeout,
		headers: [String: String] = [:]
	) {
		self.init(
			server: server,
			invocation: invocation,
			timeout: timeout,
			headers: headers,
			body: nil
		)
	}
}

extension LocalNetworkEngine.Request: Equatable where T: Equatable {}
extension LocalNetworkEngine.Request: Hashable where T: Hashable {}

extension LocalNetworkEngine {
	struct Response: Codable, Sendable {
		let requestID: UUID

		let invocation: Invocation
		let headers: [String: String]

		let body: Data

		init(requestID: UUID, invocation: Invocation, headers: [String : String], body: Data) {
			self.requestID = requestID
			self.invocation = invocation
			self.headers = headers
			self.body = body
		}

		init<T: Codable>(
			requestID: UUID,
			invocation: Invocation,
			headers: [String : String],
			body: T
		) throws {
			let data = try LocalNetworkEngine.encoder.encode(body)
			self.init(requestID: requestID, invocation: invocation, headers: headers, body: data)
		}

		init<T: Codable>(
			fromRequest meta: LocalNetworkEngineServer.RequestMeta,
			body: T
		) throws {
			try self.init(
				requestID: meta.requestID,
				invocation: meta.invocation,
				headers: [:],
				body: body)
		}
	}
}
