import UIKit
@preconcurrency import MultipeerConnectivity

class SyncController: UIViewController {

	static let serviceTypeIdentifier = "qhristmasreader"

	private nonisolated let peerID: MCPeerID
	private nonisolated let session: MCSession
	private nonisolated let advertiser: MCNearbyServiceAdvertiser?

	private var browser: MCBrowserViewController?

	@MainActor
	private var syncStateViews: [MCPeerID: PeerSyncStateView] = [:]

	private let stackView = UIStackView().with {
		$0.axis = .vertical
		$0.alignment = .fill
		$0.distribution = .fill
	}

	init(asHost: Bool, username: String) {
		let peerID = MCPeerID(displayName: username)
		let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)

		let advertiser: MCNearbyServiceAdvertiser?
		if asHost {
			advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: Self.serviceTypeIdentifier)
		} else {
			advertiser = nil
		}

		self.peerID = peerID
		self.session = session
		self.advertiser = advertiser

		super.init(nibName: nil, bundle: nil)
		advertiser?.delegate = self
		session.delegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Peer Sync"
		navigationItem.largeTitleDisplayMode = .always
		configureViewLayout()

		if advertiser == nil {
			showBrowser()
		} else {
			startHosting()
		}
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		advertiser?.stopAdvertisingPeer()
	}

	private func startHosting() {
		guard let advertiser else { return }
		advertiser.startAdvertisingPeer()
		startPing()
	}

	private func showBrowser() {
		let browser = MCBrowserViewController(serviceType: Self.serviceTypeIdentifier, session: session)
		self.browser = browser
		browser.delegate = self
		browser.maximumNumberOfPeers = 1

		let root = navigationController ?? self

		root.present(browser, animated: true)
	}

	private func configureViewLayout() {
		var constraints: [NSLayoutConstraint] = []
		defer { NSLayoutConstraint.activate(constraints) }

		view.addSubview(stackView)
		constraints += view.constrain(stackView, inset: NSDirectionalEdgeInsets(scalar: 24))
	}

	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()

	func startPing() {
		Task {
			while true {
				try await Task.sleep(for: .seconds(2))
				guard session.connectedPeers.isOccupied else { continue }
				try session.send(encoder.encode(CommProtocol.Request.ping), toPeers: session.connectedPeers, with: .reliable)
			}
		}
	}

	private func getSyncView(for peerID: MCPeerID) -> PeerSyncStateView {
		if let existing = syncStateViews[peerID] {
			return existing
		} else {
			let new = PeerSyncStateView()
			new.connectedPeer = peerID.displayName
			syncStateViews[peerID] = new
			stackView.addArrangedSubview(new)

			return new
		}
	}

	enum CommProtocol {
		enum Request: Codable {
			case listRecipientIDs
			case listGiftIDs
			case getRecipient(id: UUID)
			case getGift(id: UUID)
			case ping
		}

		enum Response {
			case recipientIDList(ids: [UUID: Date])
			case giftIDList(ids: [UUID: Date])
			case recipient(Recipient.DTO)
			case gift(Gift.DTO, Data)
			case pong
		}
	}

	private nonisolated func updateSyncView(for peerID: MCPeerID, _ block: @MainActor @escaping (PeerSyncStateView) -> Void) {
		Task { @MainActor in
			let view = getSyncView(for: peerID)

			block(view)
		}
	}

	private func removeSyncView(for peerID: MCPeerID) {
		syncStateViews[peerID]?.removeFromSuperview()
		syncStateViews[peerID] = nil
	}
}

extension SyncController: MCSessionDelegate {
	nonisolated
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		Task {
			switch state {
			case .notConnected:
				print("\(peerID) disconnected")
				await removeSyncView(for: peerID)
			case .connecting:
				print("\(peerID) is connecting")
				updateSyncView(for: peerID) {
					$0.connectedPeer = peerID.displayName
					$0.state = .connecting
				}
			case .connected:
				updateSyncView(for: peerID) { [weak self] in
					$0.connectedPeer = peerID.displayName
					$0.state = .connected
					self?.browser?.dismiss(animated: true)
				}
			@unknown default:
				fatalError("Unknown state: \(state)")
			}
		}
	}
	
	nonisolated
	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		print("\(#function): \(peerID) - \(data)")
	}
	
	nonisolated
	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		print("\(#function): \(peerID) - \(streamName)")
	}
	
	nonisolated
	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		print("\(#function): \(peerID) - \(resourceName)")
	}
	
	nonisolated
	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {
		print("\(#function): \(peerID) - \(resourceName)")
	}
}

extension SyncController: MCBrowserViewControllerDelegate {
	nonisolated
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
		}
	}

	nonisolated
	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		Task { @MainActor in
			browserViewController.dismiss(animated: true)
		}
	}

	nonisolated
	func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
		print("\(#function): \(peerID) - \(info as Any)")
		return true
	}
}

extension SyncController: MCNearbyServiceAdvertiserDelegate {
	nonisolated
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
		print("\(#function): \(peerID) - \(error)")
	}

	nonisolated
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		print("\(#function): \(peerID) - \(context as Any)")

		invitationHandler(true, session)
	}
}
