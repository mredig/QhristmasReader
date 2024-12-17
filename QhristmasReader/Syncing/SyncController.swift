import UIKit
import MultipeerConnectivity

class SyncController: UIViewController {

	static let serviceTypeIdentifier = "qhristmasreader"

	private let peerID: MCPeerID
	private let session: MCSession
//	private let advertiserAssitant: MCAdvertiserAssistant?
	private let advertiser: MCNearbyServiceAdvertiser?

	private var browser: MCBrowserViewController?

	init(asHost: Bool, username: String) {
		let peerID = MCPeerID(displayName: username)
		let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)

		let advertiser: MCNearbyServiceAdvertiser?
		if asHost {
//			advertiser = MCAdvertiserAssistant(serviceType: Self.serviceTypeIdentifier, discoveryInfo: nil, session: session)
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

		view.backgroundColor = .systemPink

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
//		browser.browser?.delegate = self

		let root = navigationController ?? self

		root.present(browser, animated: true)
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
}

extension SyncController: MCSessionDelegate {
	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		print("\(#function): \(peerID) - \(state)")
		switch state {
		case .notConnected:
			print("\(peerID) disconnected")
		case .connecting:
			print("\(peerID) is connecting")
		case .connected:
			print("\(peerID) connected")
		@unknown default:
			fatalError("Unknown state: \(state)")
		}
	}
	
	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		print("\(#function): \(peerID) - \(data)")
	}
	
	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
		print("\(#function): \(peerID) - \(streamName)")
	}
	
	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
		print("\(#function): \(peerID) - \(resourceName)")
	}
	
	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {
		print("\(#function): \(peerID) - \(resourceName)")
	}
}

extension SyncController: MCBrowserViewControllerDelegate {
	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		browserViewController.dismiss(animated: true)
	}

	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		browserViewController.dismiss(animated: true)
	}

	func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
		print("\(#function): \(peerID) - \(info as Any)")
		return true
	}
}

extension SyncController: MCNearbyServiceBrowserDelegate {
	func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
		print("\(#function): \(peerID)")
		self.browser?.browser(browser, lostPeer: peerID)
	}

	func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
		print("\(#function): \(peerID) - \(info as Any)")
		self.browser?.browser(browser, foundPeer: peerID, withDiscoveryInfo: info)
	}

	func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: any Error) {
		print("\(#function): \(peerID) - \(error)")
		self.browser?.browser(browser, didNotStartBrowsingForPeers: error)
	}
}

extension SyncController: MCNearbyServiceAdvertiserDelegate {
	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: any Error) {
		print("\(#function): \(peerID) - \(error)")
	}

	func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
		print("\(#function): \(peerID) - \(context as Any)")

		invitationHandler(true, session)
	}
}
